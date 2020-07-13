
Flocking.fx の ikUnderwater対応

これは針金P作 Flocking.fx を ikUnderwaterで正しく扱うためのエフェクトファイル群です。


■ 使い方

□ 最初に

1. このファイルのあるフォルダをikUnderwaterの下にコピーする必要があります。

つまり、ikUnderwater/ikUnderwater.x のあるフォルダに uwFlocking以下をコピーし、
ikUnderwater/uwFlocking/readme.txtになるようにする必要があります。


□ Flockingのセットアップ

1. Flocking.xをMMDにロードする。
2. fish[Flocking_Obj.fx].x をロードする。
3. 0フレームを再生する。

	これで適当な位置に魚が出現します。

4. Flocking.xとfish[Flocking_Obj.fx].xは ikUnderwaterより手前に表示させる必要があります。


□ ikUnderwater用のセットアップ

1. MMEのタブを開く。
2. LightSpaceDepthタブの fish[Flocking_Obj.fx].x (Flocking_Obj.fxを割り当てたモデル) に
	for_UW/FlockingShadowBuffer.fx を割り当てる。
	以下同様に、
		CameraSpaceDepth に、for_UW/FlockingLinearDepth.fx
		ReflectionMapに、for_UW/FlockingReflection.fx
		RefractionMapに、for_UW/FlockingRefraction.fx
	を割り当てる。

3. 上記4タブ内の、Flocking.x はチェックを外したほうがよい。


細かい使い方は針金Pのreadme.txtを参照してください。



ikeno
twitter: @ikeno_mmd

