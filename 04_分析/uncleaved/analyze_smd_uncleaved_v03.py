#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
analyze_smd_uncleaved_v03.py — 解析 SMD(DUMPAVE)输出,绘制力-位移 / 拉力-时间 / 做功曲线。

DUMPAVE 文件(pmdemd/pmemd.cuda jar=1 模式)每 DUMPFREQ 步一行,4 列:
  1. 约束目标位置 r2(Å)  —— 恒速拉动下随时间线性推进,【不是时间】
  2. 实际 COM 距离(Å)     —— 两基团质心的真实距离(反应坐标)
  3. 约束弹簧力(kcal/mol/Å) = 2·rk2·Δr(rk2 = 7.2)
  4. 累计功(kcal/mol)     —— 单段内累计;分片运行时各段从 0 重启,本脚本自动跨段累计

run_smd_uncleaved_v03.sh 分片运行把各段 smd_chunkNN.out 按序合并成 smd.out(目标位置连续),
本脚本据此由目标位置/拉速反推时间,并把各段功拼接成全程累计功。

时间起点 R0 取数据首行目标位置 r2[0](= 各体系 smd_uncleaved_v02.RST 的起始 r2),因此支持
各体系自定义 R0(如按各自平衡 COM 距离设定),时间轴总是从 0 起。

段边界检测(v3, 2026-08-17 修复): DUMPAVE 每个 run(每分片)首行累计功恒为
  0.00000,故【段起点 = 累计功精确为 0 的行】。v2 的"功掉 1 kcal/mol 以上且落回
  0 附近(|w|<0.5)"启发式在慢速(1 Å/ns)下失效:多段末功 < 1 kcal/mol 时边界被
  漏检,与其后段合并,导致累计功被低估(生产数据实测 cleaved 45.5→49.7、
  uncleaved 62.9→65.2 kcal/mol)。w 精确为 0 的标记与力幅无关,各拉速均可靠。
解离峰值取【拉伸正力】(弹簧把界面拉开的力);负力 = 压缩, 是 R0 与平衡距离
  不匹配的装载伪迹, 不参与解离统计(但会在输出中提示)。
额外输出 5 点平滑峰(单点峰可能是热涨落尖峰)与 ∫F·dr2 交叉校验(应为
  Σ段末行功的 1–2% 内)。

用法:
  python analyze_smd_uncleaved_v03.py smd.out [--speed 5] [--plot] [--out smd_curves]
    --speed 5  拉速(Å/ns),用于由目标位置反推时间:5 Å/ns 初筛 / 1 Å/ns 定量
    --plot     生成 2×2 曲线图(smd_curves.png)

依赖: numpy, matplotlib(中文图需系统含 CJK 字体,见脚本内 FONT 配置)
"""
import sys, os
import numpy as np

try:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    HAS_PLT = True
except ImportError:
    HAS_PLT = False

# --- 中文字体:按系统可用字体设置;若全是豆腐块,安装 fonts-noto-cjk 后重试
FONT = "Noto Sans CJK SC"
try:
    import matplotlib.font_manager as fm
    fams = {f.name for f in fm.fontManager.ttflist}
    if FONT not in fams:
        import subprocess
        out = subprocess.run(["fc-list", ":lang=zh", "-f", "%{family}\\n"],
                             capture_output=True, text=True).stdout
        cand = [l.strip() for l in out.splitlines() if l.strip()]
        if cand:
            FONT = cand[0]
            print(f"[字体] 使用 {FONT}")
except Exception:
    pass
if HAS_PLT:
    matplotlib.rcParams["font.sans-serif"] = [FONT, "DejaVu Sans"]
    matplotlib.rcParams["axes.unicode_minus"] = False

KCAL_TO_PN = 69.48    # 1 kcal/mol/Å ≈ 69.48 pN


def parse(path):
    """读 DUMPAVE,返回 (r2_target, dist, force, work)。跳过无法解析的行。"""
    r2, d, f, w = [], [], [], []
    with open(path) as fh:
        for line in fh:
            toks = line.split()
            if len(toks) < 4:
                continue
            try:
                vals = [float(x) for x in toks[:4]]
            except ValueError:
                continue
            r2.append(vals[0]); d.append(vals[1])
            f.append(vals[2]);  w.append(vals[3])
    if not r2:
        raise SystemExit(f"错误: {path} 未解析出数据行。请确认 smd_pull_uncleaved_v03.mdin 含 "
                         "&wt type='DUMPFREQ' 使 DUMPAVE 有输出。")
    return (np.array(r2), np.array(d), np.array(f), np.array(w))


def find_chunk_starts(w):
    """返回各分片起点行索引(段边界)。

    段起点 = 累计功精确为 0 的行:DUMPAVE 每个 run(每分片)的首行功恒打印为
    0.00000(每次 run 从 0 重新累计)。慢速拉动下各段末功常 < 1 kcal/mol,
    基于"功掉落 >1 kcal/mol"的启发式会漏检这些边界而低估总功,故改为本标记。
    """
    w = np.asarray(w, dtype=float)
    return np.where(w == 0.0)[0]


def cumulative_work(w, starts):
    """分片合并后各段功从 0 重启,按段起点拼接为全程累计功。

    每段取 [starts[k], starts[k+1]) 的行(下一段起点那一行属于下一段),
    末段到数据末行;各段首行功 = 0, 段末行功 = 该段 Amber 累计功。
    """
    w = np.asarray(w, dtype=float)
    starts = np.asarray(starts, dtype=int)
    cum = np.empty_like(w)
    offset = 0.0
    for k in range(len(starts)):
        i0 = starts[k]
        i1 = starts[k + 1] - 1 if k + 1 < len(starts) else len(w) - 1
        seg = w[i0:i1 + 1]
        cum[i0:i1 + 1] = seg - seg[0] + offset
        offset += seg[-1] - seg[0]
    return cum


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    path = sys.argv[1]
    plot = "--plot" in sys.argv
    outbase = "smd_curves"
    speed = 5.0
    for i, a in enumerate(sys.argv):
        if a == "--out" and i + 1 < len(sys.argv):
            outbase = sys.argv[i + 1]
        elif a == "--speed" and i + 1 < len(sys.argv):
            speed = float(sys.argv[i + 1])

    r2, d, f, w = parse(path)
    R0 = float(r2[0])                       # 起点 = 数据首行目标位置(各体系自定义)
    t = (r2 - R0) / (speed * 1e-3)          # 时间(ps) = 目标位移 / 拉速
    starts = find_chunk_starts(w)
    wc = cumulative_work(w, starts)
    nseg = len(starts)

    print(f"解析 {len(t)} 个数据点(拉速 {speed:.0f} Å/ns, {nseg} 段):")
    print(f"  目标距离    {r2[0]:.2f} → {r2[-1]:.2f} Å")
    print(f"  时间范围    {t[0]:.1f} – {t[-1]:.1f} ps (由目标位置反推, 起点 R0={R0:.2f} Å)")
    print(f"  COM 距离    {d[0]:.2f} → {d[-1]:.2f} Å  (位移 {d[-1]-d[0]:.2f} Å)")
    print(f"  累计做功    {wc[-1]:.2f} kcal/mol ≈ {wc[-1]*4.184:.1f} kJ/mol")
    # 交叉校验: ∫F·dr2(沿目标路径)应与 Σ段末行功一致(差异应 <2%)
    W_r2 = float(np.sum(f[1:] * np.diff(r2)))
    if wc[-1] != 0:
        print(f"  交叉校验    ∫F·dr2 = {W_r2:.2f} kcal/mol "
              f"(差 {abs(W_r2-wc[-1])/abs(wc[-1])*100:.1f}%, 同量级即通过)")

    # --- 初始弹簧预紧检查(R0 与平衡距离不匹配的伪迹) ---
    dr0 = r2[0] - d[0]
    if abs(dr0) > 1.5:
        print(f"  [提示] 初始弹簧伸长 Δr={dr0:+.2f} Å(力 {f[0]:+.1f} kcal/mol/Å):"
              f" smd_uncleaved_v02.RST 起点 r2 与该体系平衡 COM 距离不匹配,"
              f" 开局存在压缩/预紧瞬态;建议按平衡距离调整 R0 再投定量运行。")

    # --- 力峰值与解离检测(只看拉伸正力) ---
    fmax_abs = float(np.abs(f).max())
    print(f"  最大|力|    {fmax_abs:.1f} kcal/mol/Å ≈ {fmax_abs*KCAL_TO_PN:.0f} pN")
    if len(f) > 20:
        fl_t = np.where(f > 0, f, 0.0)          # 拉伸(正力);负力=压缩,非解离
        i_max = int(np.argmax(fl_t))
        ft = fl_t[i_max]
        if ft > 0:
            print(f"  拉伸峰值   {ft:.2f} kcal/mol/Å ≈ {ft*KCAL_TO_PN:.0f} pN"
                  f" @ COM 距离 {d[i_max]:.2f} Å (时间 ≈ {t[i_max]:.0f} ps)")
            # 5 点平滑峰:单点峰可能是热涨落尖峰,平滑峰更能代表持续抗力
            fs = np.convolve(f, np.ones(5) / 5, mode="valid")
            ism = int(np.argmax(fs))
            print(f"  平滑峰值   {fs[ism]:.2f} kcal/mol/Å ≈ {fs[ism]*KCAL_TO_PN:.0f} pN"
                  f" @ COM 距离 {d[ism+2]:.2f} Å")
            drop = np.where(fl_t[i_max:] < 0.3 * ft)[0]
            if len(drop) > 0:
                i_drop = i_max + int(drop[0])
                print(f"  解离完成   峰值后首次回落至 30% 以下, COM 距离 ≈ "
                      f"{d[i_drop]:.2f} Å (时间 ≈ {t[i_drop]:.0f} ps)")

    # 保存曲线数据: 时间 目标r2 实际距离 力 累计功
    np.savetxt(f"{outbase}.dat", np.column_stack([t, r2, d, f, wc]),
               header="t_ps  r2_target_Ang  dist_Ang  "
                      "force_kcal_per_mol_per_Ang  work_cum_kcal_per_mol")

    if plot and HAS_PLT:
        fig, axes = plt.subplots(2, 2, figsize=(11, 8))
        axes[0, 0].plot(t, f, "-", lw=0.8, color="#1f77b4")
        axes[0, 0].axhline(0, color="#7f7f7f", lw=0.6)
        axes[0, 0].set_xlabel("时间 (ps)"); axes[0, 0].set_ylabel("力 (kcal/mol/Å)")
        axes[0, 0].set_title("拉力-时间")
        axes[0, 1].plot(d, f, "-", lw=0.8, color="#1f77b4")
        axes[0, 1].axhline(0, color="#7f7f7f", lw=0.6)
        axes[0, 1].set_xlabel("COM 距离 (Å)"); axes[0, 1].set_ylabel("力 (kcal/mol/Å)")
        axes[0, 1].set_title("力-位移")
        axes[1, 0].plot(t, wc, "-", lw=0.8, color="#d62728")
        axes[1, 0].set_xlabel("时间 (ps)"); axes[1, 0].set_ylabel("功 (kcal/mol)")
        axes[1, 0].set_title("累计做功-时间")
        axes[1, 1].plot(d, wc, "-", lw=0.8, color="#d62728")
        axes[1, 1].set_xlabel("COM 距离 (Å)"); axes[1, 1].set_ylabel("功 (kcal/mol)")
        axes[1, 1].set_title("累计做功-位移")
        for a in axes.flat:
            a.spines[["top", "right"]].set_visible(False)
            a.grid(alpha=0.3)
        fig.suptitle("SMD 力驱动解离曲线", fontsize=14)
        fig.tight_layout(rect=(0, 0, 1, 0.96))
        fig.savefig(f"{outbase}.png", dpi=200)
        print(f"[图] 已保存 {outbase}.png")
    elif plot and not HAS_PLT:
        print("[警告] 未装 matplotlib,跳过绘图(已保存 .dat)")


if __name__ == "__main__":
    main()
