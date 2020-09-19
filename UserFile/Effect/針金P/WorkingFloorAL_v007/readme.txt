WorkingFloorAL.fx ver0.0.7

WorkingFloor2,WorkingFloorX を AutoLuminous(そぼろ氏作)に対応させた鏡像描画エフェクトです。
AutoLuminousを使用しない場合は無駄な処理が増えるだけなので従来通りWorkingFloor2,WorkingFloorXを
使った方がよいです。


・動作環境
AutoLuminousが動作する環境なら大丈夫なはず。
※このFXファイルはMMEver0.33以降でないと正しく動作しません。


・基本的な使用方法(AutoLuminous対応モデル,AutoLuminous本体は設定済みとして説明します)
(1)WorkingFloorAL.fxの先頭パラメータをAutoLuminous.fxと同じ設定にしてください
(2)WorkingFloorAL.xをMMDにロードします。
(3)描画順序は，背景ステージ→AutoLuminous.x→WorkingFloorAL.x→その他のオブジェクトの順を推奨します。
   WorkingFloorAL.xがAutoLuminous.xより先になると発光部は1フレーム前の物が描画されます。
(4)｢MMEffect｣→｢エフェクト割当｣のAL_EmitterRTタブよりWorkingFloorAL.xを選択してAL_WorkingFloor.fxを適用する.
   これでAutoLuminous対応モデルがあると鏡面描画のオブジェクトも自動的に発光します。
   なお、AutoLuminousのフォルダにAL_WorkingFloor.fxをコピーしてAutoLuminous.fxのAL_EmitterRT定義のセレクタ指定箇所に
             "WorkingFloorAL.x = AL_WorkingFloor.fx;"
   を追加しておくと、この行程はAutoLuminous.xロード時に自動で行われます.
(5)MMDのアクセサリパラメータで以下の変更を行いキーフレーム登録してください。
    Tr：鏡面の反射率
    影：反射率に対する発光強度が変化します。Trが小さめの時、発光が弱いと思う場合はONにしてください。
    その他のパラメータで鏡面の描画範囲を設定します。
    エフェクトをoffにした時のWorkingFloorAL.xの白い板ポリ内が描画範囲になります。
(6)WorkingFloorAL.fxはデフォルトですべてのオブジェクトに対して鏡像描画するように設定されています。
   鏡像化したくないモデルやエフェクト設定モデルなど描画すべきでないオブジェクトは
   ｢MMEffect｣→｢エフェクト割当｣のWorkingFloorRT､WF_EmitterRTタブより非表示選択してください。
   またはWorkingFloorAL.fx内のWorkingFloorRT､WF_EmitterRT定義の所定箇所でオブジェクト選択編集してください。


・MikuMikuMovingについて
このエフェクトはMikuMikuMovingにも対応しています。
WorkingFloorAL.fx,WorkingFloorAL.xの両方をMikuMikuMovingにロードしてご利用下さい。
オフスクリーンの設定はWorkingFloorAL.xにたいして行います。
MMMでは鏡面描画の反射率をWorkingFloorAL.fxのα値、発光の鏡面反射をWorkingFloorAL.xのα値で調節します。
※MMMではどのような描画順序でも発光部は1フレーム遅れて描画されるっぽいです。


・ObjectLuminous方式の発光方法
Option\OL_Selectorフォルダにあるセレクタエフェクトを使って指定するモデル･材質の鏡像を発光させることが出来ます。
(1)AL_EmitterRTタブの発光させたいモデル･材質にOL_Select.fxを適用してください。オブジェクト自身が発光します。
(2)WF_EmitterRTタブの同じモデル･材質にOL_MirrorSelect.fxを適用してください。オブジェクトの鏡像が発光します。
(3)発光強度、発光色はそれぞれのセレクタの先頭パラメータで調整してください。
(4)複数のモデル･材質にパラメータを変えて適用させたい場合は、セレクタファイルを別名でコピーして同様の設定を行ってください。


・マスク機能について
AutoLuminousのオブジェクト発光をマスクする機能を鏡像描画でも行うことが出来ます。
(1)AutoLuminousのマスク機能設定を行ってください(MMEタブにAL_MaskRTが追加されている状態)。
(2)WorkingFloorAL.fxの先頭パラメータでマスク機能をオンにしてください。MMEタブにWF_MaskRTが追加されます。
(3)WF_MaskRTタブよりマスクしたいオブジェクトを選択して、Option\AL_MaskフォルダにあるWF_BlackMask.fxを適用してください。
(4)AL_MaskRTタブよりWorkingFloorAL.xを選択して、AL_WorkingFloorMask.fxを適用する。
   これで鏡面描画のオブジェクトも発光がマスクされます。
   なお、AutoLuminousのフォルダにAL_WorkingFloorMask.fxをコピーしてAutoLuminous.fxのAL_MaskRT定義の所定箇所に
             "WorkingFloorAL.x = AL_WorkingFloorMask.fx;"
   を追加しておくと、この行程はAutoLuminous.xロード時に自動で行われます.


・テクスチャ発光
AutoLuminousのAL_Texture.fxエフェクトと同等のことが鏡像描画でも行うことが出来ます。
WF_EmitterRTタブでテクスチャ発光させたい材質にOptionフォルダにあるWF_TextureEmit.fxを適用してください。


・Xシャドウ描画について
WorkingFloorXと同等のXシャドウ描画を行うことが出来ます。デフォルトでは非表示になっています。
表示させたい場合はWorkingFloorAL.fxの先頭パラメータでXシャドウ描画をオンにしてください。
X影はWorkingFloorAL.xの高さ(アクセサリパラメータYの高さ)に描画されます。鏡面の傾きには連動しません。


・その他
WorkingFloorAL.xを別形状のモデルに置き換えることで任意形状の鏡面を作成することが出来ます(平面限定ですが)。
デフォルトではXZ平面(Y=0)で作成してください.

このエフェクトはMMDのアクセサリパラメータで位置や傾きを変えることで床面だけでなく任意平面への
鏡像も可能な鏡面エフェクトになっています。
直接アクセサリに組み込む場合は各エフェクトファイルのパラメータ変更が必要になります。

このエフェクトは発光だけでなく鏡像のオブジェクト描画についてもAutoLuminousのHDRレンダリングに対応しています。
MMD標準描画の加算合成で１を超える色は高照度情報として鏡像描画も含めてAutoLuminousに渡され発光の対象となります。
ただし、他のエフェクトによる加算は鏡像には反映されないため対象外です。


・注意点
WorkingFloorAL.xを複数ロードすると正常に動作しなくなりますので注意してください。

一部のグラフィックボードでモデルの鏡像が正常に描画されない(モデルが黒または白になる)ことが
あります。この場合、WorkingFloorAL.fxの先頭パラメータFLG_EXCEPTIONを変更してご利用ください。


・TrueCameraLXの対応について
このエフェクトはTrueCameraLX(そぼろ氏作)で鏡像のブラーや被写界深度にも一応対応可能になっています。
(1)描画順序は，背景ステージ→TrueCameraLX.x→WorkingFloorAL.x→その他のオブジェクトの順を推奨します。
   WorkingFloorAL.xがTrueCameraLX.xより先になると発光部は1フレーム前の物が描画されます。
(2)WorkingFloorAL.fxの先頭パラメータでTrueCameraLX使用をオンにしてください。MMEタブにWF_DVMapDrawが追加されます。
(3)DVMapDrawタブよりWorkingFloorAL.xを選択してTCLX_WorkingFloor.fxを適用する.
   これで鏡面描画のオブジェクトもブラーや被写界深度が掛かるようになります。
※実際のところ鏡面のブラー&被写界深度が正常に描画されるのは鏡面が完全反射(Tr=1)の時に限られます(エフェクトを掛けるのに
  必要な深度や速度情報が、半透明では鏡像と床面のどちらか片方の情報しかTrueCameraLXに送れないため)。
  半透明描画の際、床面のブラー&被写界深度が不自然になる場合はWF_DVMapDrawタブで背景モデルは非表示した方が良いかもしれません。


・更新履歴
v0.0.7  2015/10/17  X影の描画高さを鏡面の高さに合わせるようにした。
v0.0.6  2013/11/17  一部のグラボで鏡像モデルが正常に描画されない不具合への対応
                    一部のグラボでX影が正常に描画されなかった不具合の修正
                    FXファイル先頭でX影の色変更パラメータ追加
v0.0.5  2013/07/06   AutoLuminous4, TrueCameraLX3.2 の追加機能への対応
                     MMEシェーダを新しいバージョン(v0.33以降)仕様にした(PMXの材質モーフ､サブTex等に対応)
                     MikuMikuMovingの対応
v0.0.4  2012/09/10   x64版の対応, 鏡像頂点発光のバグ修正,鏡像変換方法･X影生成方法の簡素化
                     半透明にした時に床下のモデルが発光しなかった不具合修正,TrueCameraLXに仮対応
v0.0.3  2012/03/08   AutoLuminous2.0の追加機能への対応、MikuMikuMovingは未対応です
v0.0.2  2011/11/15   アクセサリ操作の｢影｣チェックで反射率に対する発光強度変化の切り替え追加,
                     反射率を下げると鏡像にマスクが掛からなくなるバグ修正,他細かい修正
v0.0.1  2011/11/11   初回版公開


・免責事項
ご利用・改変・二次配布は自由にやっていただいてかまいません。連絡も不要です。
ただしこれらの行為は全て自己責任でやってください。
このプログラム使用により、いかなる損害が生じた場合でも当方は一切の責任を負いません。


by 針金P
Twitter : @HariganeP


