
// Based on other paper :

// Water Flow in PORTAL 2
// http://advances.realtimerendering.com/s2010/Vlachos-Waterflow(SIGGRAPH 2010 Advanced RealTime Rendering Course).pdf

// Water Foam
// http://http.developer.nvidia.com/GPUGems2/gpugems2_chapter18.html


【追加解説】

　material_common.fxsub　：直接は使用しませんが存在しないと動作しません

　material_water_bg.fx　：初心者用waterマテリアル本体

　material_water_ctrl.pmx　：上記のコントローラー

　material_water_editor.fxsub　：直接は使用しませんが存在しないと動作しません

　water.pmx　：waterマテリアルを貼り付けるための平板モデル
　　　　　　　 おまけの初心者フロアでも代用できます
　　　　　　　 拡大縮小のスケールが違うので、波の細かさが違いますから色々試してみて下さい