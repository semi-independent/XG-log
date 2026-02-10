# SD Gauge (S/D 定規セット)

このフォルダは、S系/D系調整の「効果比較用の定規」です。

## 目的
- その時点の調整が、過去基準より改善/悪化したかを相対比較する
- 直接の本番期待値としては使わない（あくまで比較用）

## 主要ファイル
- `scenario_sweep_S0_S12.csv` : S0〜S12 の旧試算表
- `direction_stage_sweep_D0_D12.csv` : D0〜D12 の旧試算表
- `joint_sweep_projection.py` : S/D 連動の旧試算スクリプト
- `joint_sweep_Sx_Dx.csv` : 連動試算の出力結果（基準）

## 使い方（Mac側）
1. ターミナルで作業ルートへ移動
   - `cd /Users/evilheart/Documents/XG/XG-EA`
2. 実行
   - `python3 src/sd_gauge/joint_sweep_projection.py`
3. 出力確認
   - `src/sd_gauge/joint_sweep_Sx_Dx.csv`

## 運用メモ
- 旧試算は「固定のものさし」。
- 実運用の最新データ（Dropbox/HUBの最新アーカイブ解析）と必ず併読すること。
