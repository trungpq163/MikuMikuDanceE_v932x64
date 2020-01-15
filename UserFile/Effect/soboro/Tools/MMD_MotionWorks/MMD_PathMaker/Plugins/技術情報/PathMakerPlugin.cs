
/*********************************************************************************************
 * 
 * PathMaker用プラグインのインターフェースと基本構造体を提供します
 * 
 * ******************************************************************************************/

using System;
using System.Collections.Generic;
using System.Drawing;
using System.Windows.Forms;

namespace PathMakerPlugin
{

    /// <summary>
    /// 3次元上の点を表す構造体。書き易さ優先で演算子のオーバーロードしまくり
    /// </summary>
    public struct Point3D
    {
        /// <summary>
        /// 要素を指定して新しいインスタンスを作成します
        /// </summary>
        public Point3D(double x, double y, double z)
        {
            px = x;
            py = y;
            pz = z;
        }

        private double px;
        private double py;
        private double pz;

        /// <summary>
        /// X軸座標
        /// </summary>
        public double X
        {
            get { return px; }
            set { px = value; }
        }
        /// <summary>
        /// Y軸座標
        /// </summary>
        public double Y
        {
            get { return py; }
            set { py = value; }
        }
        /// <summary>
        /// Z軸座標
        /// </summary>
        public double Z
        {
            get { return pz; }
            set { pz = value; }
        }

        /// <summary>
        /// 点の座標の実数倍
        /// </summary>
        public static Point3D operator *(Point3D u, double v)
        {
            u.X *= v; u.Y *= v; u.Z *= v;
            return u;
        }

        /// <summary>
        /// 点の座標の加算
        /// </summary>
        public static Point3D operator +(Point3D u, Point3D v)
        {
            u.X += v.X; u.Y += v.Y; u.Z += v.Z;
            return u;
        }

        /// <summary>
        /// 点をベクトルに従って移動
        /// </summary>
        public static Point3D operator +(Point3D u, Vector3D v)
        {
            u.X += v.X; u.Y += v.Y; u.Z += v.Z;
            return u;
        }

        /// <summary>
        /// 点と点の間のベクトルを算出
        /// </summary>
        public static Vector3D operator -(Point3D u, Point3D v)
        {
            Vector3D v3 = new Vector3D(u.X - v.X, u.Y - v.Y, u.Z - v.Z);
            return v3;
        }


    }

    /// <summary>
    /// 3次元ベクトル表す構造体。書き易さ優先で演算子のオーバーロードしまくり
    /// </summary>
    public struct Vector3D
    {
        /// <summary>
        /// 要素を指定して新しいインスタンスを作成します
        /// </summary>
        public Vector3D(double x, double y, double z)
        {
            px = x;
            py = y;
            pz = z;
        }

        private double px;
        private double py;
        private double pz;

        /// <summary>
        /// X軸成分
        /// </summary>
        public double X
        {
            get { return px; }
            set { px = value; }
        }
        /// <summary>
        /// Y軸成分
        /// </summary>
        public double Y
        {
            get { return py; }
            set { py = value; }
        }
        /// <summary>
        /// Z軸成分
        /// </summary>
        public double Z
        {
            get { return pz; }
            set { pz = value; }
        }

        /// <summary>
        /// ベクトルの大きさ
        /// </summary>
        public double Length
        {
            get { return (float)Math.Sqrt(X * X + Y * Y + Z * Z); }
        }

        /// <summary>
        /// 正規化されたベクトルを返します
        /// </summary>
        /// <returns>正規化されたベクトル</returns>
        public Vector3D Normalize()
        {
            return (this / Length);
        }

        /// <summary>
        /// ベクトルの外積（クロス積）を求める
        /// </summary>
        public static Vector3D Cross(Vector3D u, Vector3D v)
        {
            Vector3D r = new Vector3D();
            r.X = u.Y * v.Z - u.Z * v.Y;
            r.Y = u.Z * v.X - u.X * v.Z;
            r.Z = u.X * v.Y - u.Y * v.X;
            return r;
        }

        /// <summary>
        /// 成分の加算
        /// </summary>
        public static Vector3D operator +(Vector3D u, Vector3D v)
        {
            u.X += v.X; u.Y += v.Y; u.Z += v.Z;
            return u;
        }

        /// <summary>
        /// 成分の減算
        /// </summary>
        public static Vector3D operator -(Vector3D u, Vector3D v)
        {
            Vector3D v3 = new Vector3D(u.X - v.X, u.Y - v.Y, u.Z - v.Z);
            return v3;
        }

        /// <summary>
        /// ベクトルの実数倍
        /// </summary>
        public static Vector3D operator *(Vector3D u, double v)
        {
            u.X *= v; u.Y *= v; u.Z *= v;
            return u;
        }
        /// <summary>
        /// ベクトルの実数倍
        /// </summary>
        public static Vector3D operator /(Vector3D u, double v)
        {
            u.X /= v; u.Y /= v; u.Z /= v;
            return u;
        }

        /// <summary>
        /// ベクトルの内積
        /// </summary>
        public static double operator *(Vector3D u, Vector3D v)
        {
            return (u.X * v.X + u.Y * v.Y + u.Z * v.Z);
        }

    }


    /// <summary>
    /// PathMaker上のメインピクチャボックスが描画された時のイベントを提供します
    /// </summary>
    public delegate void PictureBoxPaintEventHandler(IPluginHost sender);

    /// <summary>
    /// PathMakerでデータが更新された時のイベントを提供します
    /// </summary>
    public delegate void DataRenewEventHandler(IPluginHost sender);



    /// <summary>
    /// プラグインで実装するインターフェース
    /// </summary>
    public interface IPlugin
    {
        
        /// <summary>
        /// プラグインの名前
        /// </summary>
        string Name { get;}

        /// <summary>
        /// プラグインのバージョン
        /// </summary>
        string Version { get;}

        /// <summary>
        /// プラグインの説明
        /// </summary>
        string Description { get;}

        /// <summary>
        /// プラグインのホスト
        /// </summary>
        IPluginHost Host { get; set;}

        /// <summary>
        /// プラグインを実行
        /// </summary>
        void Run();

        

    }


    /// <summary>
    /// 出力結果からプレビュー再生を行うためのインターフェース
    /// </summary>
    public interface IPlayer
    {
        /// <summary>
        /// 原点からの移動量
        /// </summary>
        Transfer tr { get; }
        /// <summary>
        /// 回転
        /// </summary>
        Quaternion qt { get; }
        /// <summary>
        /// 再生が開始されているかを示します
        /// </summary>
        bool Playing { get; }
        /// <summary>
        /// 再生中のフレーム数を取得します
        /// </summary>
        int Frame { get; }
        /// <summary>
        /// 再生中のキーフレーム番号を取得します
        /// </summary>
        int Index { get; }

        /// <summary>
        /// 再生を返します
        /// </summary>
        /// <returns>成功:true, 失敗:false</returns>
        bool Start();
        /// <summary>
        /// 次のフレームに進みます
        /// </summary>
        /// <returns>成功:true, 失敗または終了:false</returns>
        bool NextFrame();
        /// <summary>
        /// パスメイカー上に再生マーカーを描画します
        /// </summary>
        void Draw();
        /// <summary>
        /// 再生を終了します
        /// </summary>
        void End();

    }

    /// <summary>
    /// プラグインのホストで実装するインターフェイス
    /// </summary>
    public interface IPluginHost
    {
        
        /// <summary>
        /// タイトルバーにメッセージを表示する
        /// </summary>
        /// <param name="msg">表示するメッセージ</param>
        void ShowTitleMessage(string msg);

        /// <summary>
        /// マーカーの座標のリストを取得します
        /// </summary>
        void GetMarkerPoints(out Point3D[] points);

        /// <summary>
        /// マーカーごとの速度倍率のリストを取得します
        /// </summary>
        void GetMarkerSpeeds(out double[] speeds);

        /// <summary>
        /// スプライン補完された座標のリストを取得します
        /// </summary>
        void GetSplinePoints(out Point3D[] points);

        /// <summary>
        /// マーカーの座標のリストを設定します。
        /// 要素数が異なる時は速度がリセットされます。
        /// </summary>
        void SetMarkerPoints(ref Point3D[] points);

        /// <summary>
        /// マーカーごとの速度のリストを設定します
        /// </summary>
        void SetMarkerSpeeds(ref double[] speeds);

        /// <summary>
        /// 現在のボーン名を取得または設定します
        /// </summary>
        string BoneName { get; set;}

        /// <summary>
        /// カメラモードか否かを返します
        /// </summary>
        bool IsCameraMode { get; }

        /// <summary>
        /// 現在の基準速度を取得または設定します
        /// </summary>
        double Speed { get; set;}

        /// <summary>
        /// 出力ファイルの名前を取得または設定します
        /// </summary>
        string OutFileName { get; set;}

        /// <summary>
        /// 3次元上の点をピクチャボックス上の点に変換します
        /// </summary>
        PointF GetDrawPoint(Point3D point);

        /// <summary>
        /// メインの描画バッファへのGraphicsを作成して返します
        /// </summary>
        Graphics GetGraphics();

        /// <summary>
        /// 描画バッファを画面に表示します
        /// </summary>
        void PictureBoxRefresh();


        /// <summary>
        /// CSV出力の結果を返します
        /// </summary>
        /// <returns>CSV出力の文字列</returns>
        string GetOutputCSV();

        /// <summary>
        /// 出力の結果を返します
        /// </summary>
        /// <returns>出力VMDデータ</returns>
        VMDFormat GetOutput();

        /// <summary>
        /// PathMaker上のメインピクチャボックスが描画される時のイベント
        /// </summary>
        event PictureBoxPaintEventHandler PictureBoxPaintEvent;

        /// <summary>
        /// PathMakerでデータが更新された時のイベント
        /// </summary>
        event DataRenewEventHandler DataRenewEvent;

        Icon FormIcon { get;}

        /// <summary>
        /// プレビュー再生機能にアクセス
        /// </summary>
        IPlayer Player { get;}


    }




}
