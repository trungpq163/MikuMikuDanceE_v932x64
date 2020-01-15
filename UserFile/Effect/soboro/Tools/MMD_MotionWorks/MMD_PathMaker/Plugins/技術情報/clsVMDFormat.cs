
/**********************************************************************************
 * VMDFormatクラス
 * 製作：そぼろ
 * Ver.1.12
 * 2010/03/06
 * 
 * MikuMikuDanceのモーションファイルであるVMDフォーマットファイルへの
 * アクセスとデータ管理を提供します。
 * クオータニオンとオイラー角の相互変換など、面倒な部分も実装しています
 * というか自分があったらいいなと思った機能を全部ぶち込んでいます
 * 
 * ポーズデータのインポート、エクスポートが可能です
 * Cloneメソッドによるコピーに対応しています
 * 現状での未解決は、カメラレコードデータの末尾の4バイトが不明です（とりあえず0埋め）
 * エラー処理は十分とはいえませんので、利用の際はご注意ください
 * また、MMDが受け入れ可能な値の範囲のチェックは行っていません
 * 
 * DirectXを使いたくなかったので、DirectXなら簡単にやってくれる部分も全部書き起こし…
 * 
 * プログラミング作法的にあるまじきクソ長さですが、分割すると使いまわす時に
 * 面倒なので、ご了承ください
 * 
 * 使用例：
 
   VMDFormat vmd = new VMDFormat();
   if(vmd.Read(@"C:\test.vmd")){
     if(vmd.MotionRecords.Count > 0) Debug.WriteLine(vmd.MotionRecords[0].BoneName);
   }
 
 ***********************************************************************************/


using System;
using System.Collections.Generic;
using System.Text;
using System.IO;
using System.Drawing;

namespace PathMakerPlugin
{
    /// <summary>
    /// VMDフォーマットファイルへのアクセスとデータ管理を提供する
    /// </summary>
    public class VMDFormat : ICloneable
    {
        /// <summary>
        /// 標準のVMDファイルのヘッダ
        /// </summary>
        public const string DefaultHeaderScript = "Vocaloid Motion Data 0002";
        /// <summary>
        /// 標準のVPDファイルのヘッダ
        /// </summary>
        public const string PoseHeaderScript = "Vocaloid Pose Data file";

        private string hdscr;
        private string actor;

        private bool actor_isdef; //モデル名が外部から変更されたか

        /// <summary>
        /// ヘッダ文字列
        /// </summary>
        public string HeaderScript
        {
            get { return hdscr; }
            set { hdscr = value; }
        }
        /// <summary>
        /// モデル名称
        /// </summary>
        public string Actor
        {
            get { return actor; }
            set { actor = value; actor_isdef = false; }
        }

        /// <summary>
        /// モーションレコードのリスト
        /// </summary>
        public List<VMDFormat.MotionRecord> MotionRecords = new List<MotionRecord>();
        /// <summary>
        /// 表情レコードのリスト
        /// </summary>
        public List<VMDFormat.ExpressionRecord> ExpressionRecords = new List<ExpressionRecord>();
        /// <summary>
        /// カメラレコードのリスト
        /// </summary>
        public List<VMDFormat.CameraRecord> CameraRecords = new List<CameraRecord>();
        /// <summary>
        /// 照明レコードのリスト
        /// </summary>
        public List<VMDFormat.LightRecord> LightRecords = new List<LightRecord>();
        /// <summary>
        /// セルフシャドウレコードのリスト
        /// </summary>
        public List<VMDFormat.ShadowRecord> ShadowRecords = new List<ShadowRecord>();

        /// <summary>
        /// 初期値を設定してインスタンスを作成
        /// </summary>
        public VMDFormat()
        {
            this.Reset();
        }


        /// <summary>
        /// 格納された情報を初期化する
        /// </summary>
        public void Reset()
        {
            this.HeaderScript = DefaultHeaderScript;
            this.Actor = "初音ミク";

            this.MotionRecords.Clear();
            this.ExpressionRecords.Clear();
            this.CameraRecords.Clear();
            this.LightRecords.Clear();

            this.actor_isdef = true;
        }

        /// <summary>
        /// クラスの複製
        /// </summary>
        public object Clone()
        {
            VMDFormat vmd = new VMDFormat();
            int i;

            vmd.HeaderScript = this.HeaderScript;
            vmd.Actor = this.Actor;

            //Listの内容を延々とコピー
            for (i = 0; i < this.MotionRecords.Count; i++)
                vmd.MotionRecords.Add((MotionRecord)this.MotionRecords[i].Clone());
            for (i = 0; i < this.ExpressionRecords.Count; i++)
                vmd.ExpressionRecords.Add((ExpressionRecord)this.ExpressionRecords[i].Clone());
            for (i = 0; i < this.CameraRecords.Count; i++)
                vmd.CameraRecords.Add((CameraRecord)this.CameraRecords[i].Clone());
            for (i = 0; i < this.LightRecords.Count; i++)
                vmd.LightRecords.Add((LightRecord)this.LightRecords[i].Clone());
            for (i = 0; i < this.ShadowRecords.Count; i++)
                vmd.ShadowRecords.Add((ShadowRecord)this.ShadowRecords[i].Clone());

            return vmd;
        }

        /// <summary>
        /// VMDファイルを開いて情報を読み出す
        /// </summary>
        /// <param name="FileName">VMDファイルのフルパス</param>
        /// <returns>成功すればtrue、失敗すればfalseを返す</returns>
        public bool Read(string FileName)
        {
            bool ret;
            FileStream fs;

            if (!File.Exists(FileName)) return false;

            try
            {
                fs = new FileStream(FileName, FileMode.Open, FileAccess.Read);
            }
            catch
            {
                return false;
            }

            //Stream版Readへとリダイレクト
            ret = this.Read(fs);

            fs.Close();

            return ret;
        }

        /// <summary>
        /// VMDファイルのストリームから情報を読み出す
        /// </summary>
        /// <param name="stream">使用するストリーム</param>
        /// <returns>成功すればtrue、失敗すればfalseを返す</returns>
        public bool Read(Stream stream)
        {
            int i, RecordCount;
            BinaryReader br = new BinaryReader(stream);

            this.Reset();

            bool MotionGet = false;


            try
            {
                this.HeaderScript = StreamRead_ShiftJIS(stream, 30);
                if (this.HeaderScript.CompareTo(DefaultHeaderScript) != 0) return false;
                this.Actor = StreamRead_ShiftJIS(stream, 20);

                RecordCount = br.ReadInt32(); //モーションレコードの数を読み出し
                if (stream.Length - stream.Position < RecordCount * MotionRecord.DataLength) return MotionGet;

                //データを読み出してリストに追加
                for (i = 0; i < RecordCount; i++)
                    MotionRecords.Add(new MotionRecord(stream));

                if (stream.Position == stream.Length) return true;
                MotionGet |= (RecordCount > 0);


                RecordCount = br.ReadInt32(); //表情レコードの数を読み出し
                if (stream.Length - stream.Position < RecordCount * ExpressionRecord.DataLength) return MotionGet;

                //データを読み出してリストに追加
                for (i = 0; i < RecordCount; i++)
                    ExpressionRecords.Add(new ExpressionRecord(stream));

                if (stream.Position == stream.Length) return true;
                MotionGet |= (RecordCount > 0);


                RecordCount = br.ReadInt32(); //カメラレコードの数を読み出し
                if (stream.Length - stream.Position < RecordCount * CameraRecord.DataLength) return MotionGet;

                //データを読み出してリストに追加
                for (i = 0; i < RecordCount; i++)
                    CameraRecords.Add(new CameraRecord(stream));

                if (stream.Position == stream.Length) return true;
                MotionGet |= (RecordCount > 0);


                RecordCount = br.ReadInt32(); //照明レコードの数を読み出し
                if (stream.Length - stream.Position < RecordCount * LightRecord.DataLength) return MotionGet;

                //データを読み出してリストに追加
                for (i = 0; i < RecordCount; i++)
                    LightRecords.Add(new LightRecord(stream));

                if (stream.Position == stream.Length) return true;
                MotionGet |= (RecordCount > 0);


                RecordCount = br.ReadInt32(); //シャドウレコードの数を読み出し
                if (stream.Length - stream.Position < RecordCount * ShadowRecord.DataLength) return MotionGet;

                //データを読み出してリストに追加
                for (i = 0; i < RecordCount; i++)
                    ShadowRecords.Add(new ShadowRecord(stream));

                MotionGet |= (RecordCount > 0);

            }
            catch
            {
                return false;
            }


            return MotionGet;
        }


        /// <summary>
        /// VMDファイルを開いて情報を書き出す
        /// </summary>
        /// <param name="FileName">VMDファイルのフルパス</param>
        /// <returns>成功すればtrue、失敗すればfalseを返す</returns>
        public bool Write(string FileName)
        {
            bool ret;
            FileStream fs;

            //ディレクトリが無ければエラー
            if (!Directory.Exists(Path.GetDirectoryName(FileName))) return false;

            try
            {
                fs = new FileStream(FileName, FileMode.Create, FileAccess.Write);
            }
            catch
            {
                return false;
            }

            //Stream版Writeへとリダイレクト
            ret = this.Write(fs);

            fs.Close();

            return ret;
        }

        /// <summary>
        /// VMDファイルのストリームへ情報を書き出す
        /// </summary>
        /// <param name="stream">使用するストリーム</param>
        /// <returns>成功すればtrue、失敗すればfalseを返す</returns>
        public bool Write(Stream stream)
        {
            BinaryWriter bw = new BinaryWriter(stream);

            try
            {

                StreamWrite_ShiftJIS(stream, this.HeaderScript, 30);
                StreamWrite_ShiftJIS(stream, this.Actor, 20);

                bw.Write(this.MotionRecords.Count);
                foreach (Record rec in MotionRecords) rec.Write(stream);

                bw.Write(this.ExpressionRecords.Count);
                foreach (Record rec in ExpressionRecords) rec.Write(stream);

                bw.Write(this.CameraRecords.Count);
                foreach (Record rec in CameraRecords) rec.Write(stream);

                bw.Write(this.LightRecords.Count);
                foreach (Record rec in LightRecords) rec.Write(stream);

                if (this.ShadowRecords.Count <= 0) return true;
                bw.Write(this.ShadowRecords.Count);
                foreach (Record rec in ShadowRecords) rec.Write(stream);

            }
            catch
            {
                return false;
            }

            return true;
        }


        /////////////////////////////////////////////////////////////////////////////////////////////////

        /// <summary>
        /// VPDファイルへ情報を書き出す
        /// </summary>
        /// <param name="FrameNumber">書き出したいフレーム番号</param>
        /// <param name="FileName">VPDファイルのフルパス</param>
        /// <returns>成功すればtrue、失敗すればfalseを返す</returns>
        public bool ExportPoseData(int FrameNumber, string FileName)
        {
            bool ret;
            FileStream fs;

            //ディレクトリが無ければエラー
            if (!Directory.Exists(Path.GetDirectoryName(FileName))) return false;

            try
            {
                fs = new FileStream(FileName, FileMode.Create, FileAccess.Write);
            }
            catch
            {
                return false;
            }

            //Stream版Writeへとリダイレクト
            ret = this.ExportPoseData(FrameNumber, fs);

            fs.Close();

            return ret;
        }

        /// <summary>
        /// VPDファイルのストリームへ情報を書き出す
        /// </summary>
        /// <param name="FrameNumber">書き出したいフレーム番号</param>
        /// <param name="stream">使用するストリーム</param>
        /// <returns>成功すればtrue、失敗すればfalseを返す</returns>
        public bool ExportPoseData(int FrameNumber, Stream stream)
        {
            Encoding Shift_JIS = Encoding.GetEncoding(932);

            string strout1 = PoseHeaderScript;
            StringBuilder strout2 = new StringBuilder();

            const string fmt1 = "0.000000";

            int i = 0;

            foreach (MotionRecord rec in MotionRecords)
            {
                if (rec.FrameNumber == FrameNumber)
                {
                    StringBuilder s = new StringBuilder();
                    s.Append("Bone"); s.Append(i); s.Append("{"); s.Append(rec.BoneName); s.AppendLine();
                    s.Append("  "); s.AppendFormat(rec.Trans.ToString(fmt1));
                    s.Append("\t\t\t\t"); s.Append("// trans x,y,z"); s.AppendLine();
                    s.Append("  "); s.AppendFormat(rec.Qt.ToString(fmt1));
                    s.Append("\t\t"); s.Append("// Quatanion x,y,z,w"); s.AppendLine(); //一応誤字も再現
                    s.AppendLine("}");
                    s.AppendLine();

                    strout2.Append(s.ToString());

                    i++;
                }
            }

            if (i == 0) return false;

            strout1 = strout1 + Environment.NewLine + Environment.NewLine;
            strout1 = strout1 + this.actor + ".osm;\t\t// 親ファイル名" + Environment.NewLine;
            strout1 = strout1 + i.ToString() + ";\t\t\t\t// 総ポーズボーン数" + Environment.NewLine;
            strout1 = strout1 + Environment.NewLine + strout2.ToString();

            StreamWriter sw = new StreamWriter(stream, Shift_JIS);

            sw.Write(strout1);

            return true;

        }





        /// <summary>
        /// VPDファイルから情報を読み出す
        /// </summary>
        /// <param name="FrameNumber">読み込み先のフレーム番号</param>
        /// <param name="FileName">VPDファイルのフルパス</param>
        /// <returns>成功すればtrue、失敗すればfalseを返す</returns>
        public bool ImportPoseData(int FrameNumber, string FileName)
        {
            bool ret;
            FileStream fs;

            if (!File.Exists(FileName)) return false;

            try
            {
                fs = new FileStream(FileName, FileMode.Open, FileAccess.Read);
            }
            catch
            {
                return false;
            }

            //Stream版Readへとリダイレクト
            ret = this.ImportPoseData(FrameNumber, fs);

            fs.Close();

            return ret;
        }

        /// <summary>
        /// VPDファイルのストリームから情報を読み込む
        /// </summary>
        /// <param name="FrameNumber">読み込み先のフレーム番号</param>
        /// <param name="stream">使用するストリーム</param>
        /// <returns>成功すればtrue、失敗すればfalseを返す</returns>
        public bool ImportPoseData(int FrameNumber, Stream stream)
        {
            Encoding Shift_JIS = Encoding.GetEncoding(932);
            StreamReader sr = new StreamReader(stream, Shift_JIS);

            string strin;
            int i, num;

            strin = sr.ReadLine(); //ヘッダ

            if (!strin.StartsWith(PoseHeaderScript)) return false;

            sr.ReadLine();
            strin = sr.ReadLine(); //モデル名

            //VMDのモデル名が指定されていない時は、ポーズデータのモデル名を設定
            if (actor_isdef)
            {
                this.actor = strin.Substring(0, strin.IndexOf(";"));
                this.actor = this.actor.Replace(".osm", "");
                this.actor = this.actor.Replace(".pmd", "");
            }

            strin = sr.ReadLine(); //ボーン数
            strin = strin.Substring(0, strin.IndexOf(";"));
            num = int.Parse(strin);

            for (i = 0; i < num; i++)
            {
                MotionRecord newrec = new MotionRecord();
                string[] strs;

                sr.ReadLine();

                strin = sr.ReadLine(); //ボーン名
                newrec.BoneName = strin.Substring(strin.IndexOf('{') + 1);

                strin = sr.ReadLine(); //Trans
                strin = strin.Substring(0, strin.IndexOf(";"));
                strin = strin.Replace(" ", "");
                strs = strin.Split(',');
                newrec.Trans.x = float.Parse(strs[0]);
                newrec.Trans.y = float.Parse(strs[1]);
                newrec.Trans.z = float.Parse(strs[2]);

                strin = sr.ReadLine(); //回転
                strin = strin.Substring(0, strin.IndexOf(";"));
                strin = strin.Replace(" ", "");
                strs = strin.Split(',');
                newrec.Qt.x = float.Parse(strs[0]);
                newrec.Qt.y = float.Parse(strs[1]);
                newrec.Qt.z = float.Parse(strs[2]);
                newrec.Qt.w = float.Parse(strs[3]);

                sr.ReadLine(); //}

                MotionRecords.Add(newrec);
            }

            return true;

        }






        /////////////////////////////////////////////////////////////////////////////////////////////////

        /// <summary>
        /// 各レコードの基本クラス
        /// </summary>
        public abstract class Record : IComparable, ICloneable
        {

            private int _FrameNumber = 0;

            /// <summary>
            /// フレーム番号
            /// </summary>
            public int FrameNumber
            {
                get { return _FrameNumber; }
                set { _FrameNumber = value; }
            }

            /// <summary>
            /// フレーム番号の大小を返します
            /// </summary>
            /// <param name="other">比較するレコード</param>
            /// <returns>フレーム番号の差</returns>
            public int CompareTo(object other)
            {
                return (this.FrameNumber - ((Record)other).FrameNumber);
            }

            /// <summary>
            /// ストリームから単独のレコードを読み出す
            /// </summary>
            abstract public void Read(Stream stream);
            /// <summary>
            /// ストリームに単独のレコードを書き出す
            /// </summary>
            abstract public void Write(Stream stream);
            /// <summary>
            /// クラスの複製
            /// </summary>
            abstract public object Clone();

        }

        /////////////////////////////////////////////////////////////////////////////////////////////////

        /// <summary>
        /// モーションレコードの情報を格納するクラス
        /// </summary>
        public class MotionRecord : Record, IComparable<MotionRecord>
        {

            public MotionRecord() { }

            /// <summary>
            /// インスタンスの作成と同時にデータを読み出す
            /// </summary>
            public MotionRecord(Stream stream)
            {
                this.Read(stream);
            }

            /// <summary>
            /// クラスの複製
            /// </summary>
            public override object Clone()
            {
                //値型しか持たないのでMemberwiseCloneで済ませる
                return this.MemberwiseClone();
            }


            /// <summary>
            /// ボーン名
            /// </summary>
            public string BoneName = " ";

            /// <summary>
            /// 平行移動の情報
            /// </summary>
            public Transfer Trans = Transfer.GetDefault();

            /// <summary>
            /// 回転の情報 (クオータニオン)
            /// </summary>
            public Quaternion Qt = Quaternion.GetDefault();

            /// <summary>
            /// X軸座標の補完曲線
            /// </summary>
            public ComplementBezier CBX = ComplementBezier.GetDefault();
            /// <summary>
            /// Y軸座標の補完曲線
            /// </summary>
            public ComplementBezier CBY = ComplementBezier.GetDefault();
            /// <summary>
            /// Z軸座標の補完曲線
            /// </summary>
            public ComplementBezier CBZ = ComplementBezier.GetDefault();
            /// <summary>
            /// 回転の補完曲線
            /// </summary>
            public ComplementBezier CBQ = ComplementBezier.GetDefault();

            /// <summary>
            /// フレーム番号の大小を比較します。フレーム番号が同じならボーン名を比較します
            /// </summary>
            /// <param name="other">比較するモーションレコード</param>
            /// <returns></returns>
            public int CompareTo(MotionRecord other)
            {
                int d1 = this.FrameNumber - other.FrameNumber;
                if (d1 == 0) d1 = this.BoneName.CompareTo(other.BoneName);

                return d1;
            }

            /// <summary>
            /// ファイル書き込み時のデータ長
            /// </summary>
            public static int DataLength { get { return 111; } }

            /// <summary>
            /// ストリームから単独のレコードを読み出す
            /// </summary>
            public override void Read(Stream stream)
            {
                BinaryReader br = new BinaryReader(stream);

                this.BoneName = StreamRead_ShiftJIS(stream, 15);

                this.FrameNumber = br.ReadInt32();
                this.Trans.x = br.ReadSingle();
                this.Trans.y = br.ReadSingle();
                this.Trans.z = br.ReadSingle();
                this.Qt.x = br.ReadSingle();
                this.Qt.y = br.ReadSingle();
                this.Qt.z = br.ReadSingle();
                this.Qt.w = br.ReadSingle();

                read_cb(br, ref CBX);
                read_cb(br, ref CBY);
                read_cb(br, ref CBZ);
                read_cb(br, ref CBQ);
            }

            /// <summary>
            /// ストリームに単独のレコードを書き出す
            /// </summary>
            public override void Write(Stream stream)
            {
                BinaryWriter bw = new BinaryWriter(stream);

                StreamWrite_ShiftJIS(stream, this.BoneName, 15);

                bw.Write(this.FrameNumber);
                bw.Write(this.Trans.x);
                bw.Write(this.Trans.y);
                bw.Write(this.Trans.z);
                bw.Write(this.Qt.x);
                bw.Write(this.Qt.y);
                bw.Write(this.Qt.z);
                bw.Write(this.Qt.w);

                write_cb(bw, ref CBX);
                write_cb(bw, ref CBY);
                write_cb(bw, ref CBZ);
                write_cb(bw, ref CBQ);

            }

            /// <summary>
            /// 補完パターンの読み出し
            /// </summary>
            private void read_cb(BinaryReader br, ref ComplementBezier cb)
            {
                //上位3バイトはダミーデータと思われる
                cb.point1.X = (int)(br.ReadUInt32() & 0x7F);
                cb.point1.Y = (int)(br.ReadUInt32() & 0x7F);
                cb.point2.X = (int)(br.ReadUInt32() & 0x7F);
                cb.point2.Y = (int)(br.ReadUInt32() & 0x7F);
            }

            /// <summary>
            /// 補完パターンの書き出し
            /// </summary>
            private void write_cb(BinaryWriter bw, ref ComplementBezier cb)
            {
                bw.Write(cb.point1.X);
                bw.Write(cb.point1.Y);
                bw.Write(cb.point2.X);
                bw.Write(cb.point2.Y);
            }

        }

        /////////////////////////////////////////////////////////////////////////////////////////////////

        /// <summary>
        /// 表情レコードの情報を格納するクラス
        /// </summary>
        public class ExpressionRecord : Record
        {

            public ExpressionRecord() { }

            /// <summary>
            /// インスタンスの作成と同時にデータを読み出す
            /// </summary>
            public ExpressionRecord(Stream stream)
            {
                this.Read(stream);
            }

            /// <summary>
            /// クラスの複製
            /// </summary>
            public override object Clone()
            {
                //値型しか持たないのでMemberwiseCloneで済ませる
                return this.MemberwiseClone();
            }

            /// <summary>
            /// 表情の名前
            /// </summary>
            public string ExpressionName = " ";

            /// <summary>
            /// 表情パラメータ
            /// </summary>
            public float Factor = 0;


            /// <summary>
            /// ファイル書き込み時のデータ長
            /// </summary>
            public static int DataLength { get { return 23; } }

            /// <summary>
            /// ストリームから単独のレコードを読み出す
            /// </summary>
            public override void Read(Stream stream)
            {
                BinaryReader br = new BinaryReader(stream);

                this.ExpressionName = StreamRead_ShiftJIS(stream, 15);

                this.FrameNumber = br.ReadInt32();
                this.Factor = br.ReadSingle();

            }

            /// <summary>
            /// ストリームに単独のレコードを書き出す
            /// </summary>
            public override void Write(Stream stream)
            {
                BinaryWriter bw = new BinaryWriter(stream);

                StreamWrite_ShiftJIS(stream, this.ExpressionName, 15);

                bw.Write(this.FrameNumber);
                bw.Write(this.Factor);
            }
        }

        /////////////////////////////////////////////////////////////////////////////////////////////////

        /// <summary>
        /// カメラレコードの情報を格納するクラス
        /// </summary>
        public class CameraRecord : Record
        {

            public CameraRecord() { }

            /// <summary>
            /// インスタンスの作成と同時にデータを読み出す
            /// </summary>
            public CameraRecord(Stream stream)
            {
                this.Read(stream);
            }

            /// <summary>
            /// クラスの複製
            /// </summary>
            public override object Clone()
            {
                //値型しか持たないのでMemberwiseCloneで済ませる
                return this.MemberwiseClone();
            }

            /// <summary>
            /// カメラ距離
            /// </summary>
            public float Distance = 0;

            /// <summary>
            /// 平行移動の情報
            /// </summary>
            public Transfer Trans = Transfer.GetDefault();

            /// <summary>
            /// 回転の情報（オイラー角：ラジアン）
            /// </summary>
            public EulerAngle Ang = EulerAngle.GetDefault();

            /// <summary>
            /// X軸座標の補完曲線
            /// </summary>
            public ComplementBezier CBX = ComplementBezier.GetDefault();
            /// <summary>
            /// Y軸座標の補完曲線
            /// </summary>
            public ComplementBezier CBY = ComplementBezier.GetDefault();
            /// <summary>
            /// Z軸座標の補完曲線
            /// </summary>
            public ComplementBezier CBZ = ComplementBezier.GetDefault();
            /// <summary>
            /// 回転の補完曲線
            /// </summary>
            public ComplementBezier CBQ = ComplementBezier.GetDefault();
            /// <summary>
            /// 距離の補完曲線
            /// </summary>
            public ComplementBezier CBD = ComplementBezier.GetDefault();
            /// <summary>
            /// 視野角の補完曲線
            /// </summary>
            public ComplementBezier CBV = ComplementBezier.GetDefault();

            /// <summary>
            /// 視野角 (25 to 125)
            /// </summary>
            public int ViewAngle = 45;



            /// <summary>
            /// ファイル書き込み時のデータ長
            /// </summary>
            public static int DataLength { get { return 61; } }

            /// <summary>
            /// ストリームから単独のレコードを読み出す
            /// </summary>
            public override void Read(Stream stream)
            {
                BinaryReader br = new BinaryReader(stream);

                this.FrameNumber = br.ReadInt32();
                this.Distance = br.ReadSingle();
                this.Trans.x = br.ReadSingle();
                this.Trans.y = br.ReadSingle();
                this.Trans.z = br.ReadSingle();
                this.Ang.x = br.ReadSingle();
                this.Ang.y = br.ReadSingle();
                this.Ang.z = br.ReadSingle();

                read_cb(br, ref CBX);
                read_cb(br, ref CBY);
                read_cb(br, ref CBZ);
                read_cb(br, ref CBQ);
                read_cb(br, ref CBD);
                read_cb(br, ref CBV);

                this.ViewAngle = br.ReadByte();
                stream.Seek(4, SeekOrigin.Current); //不明

            }

            /// <summary>
            /// ストリームに単独のレコードを書き出す
            /// </summary>
            public override void Write(Stream stream)
            {
                BinaryWriter bw = new BinaryWriter(stream);

                bw.Write(this.FrameNumber);
                bw.Write(this.Distance);
                bw.Write(this.Trans.x);
                bw.Write(this.Trans.y);
                bw.Write(this.Trans.z);
                bw.Write(this.Ang.x);
                bw.Write(this.Ang.y);
                bw.Write(this.Ang.z);

                write_cb(bw, ref CBX);
                write_cb(bw, ref CBY);
                write_cb(bw, ref CBZ);
                write_cb(bw, ref CBQ);
                write_cb(bw, ref CBD);
                write_cb(bw, ref CBV);

                bw.Write((byte)(this.ViewAngle));
                stream.Seek(4, SeekOrigin.Current); //不明
            }

            /// <summary>
            /// 補完パターンの読み出し
            /// </summary>
            private void read_cb(BinaryReader br, ref ComplementBezier cb)
            {
                //モーション補完とはデータ形式が異なる
                cb.point1.X = br.ReadByte();
                cb.point2.X = br.ReadByte();
                cb.point1.Y = br.ReadByte();
                cb.point2.Y = br.ReadByte();
            }

            /// <summary>
            /// 補完パターンの書き出し
            /// </summary>
            private void write_cb(BinaryWriter bw, ref ComplementBezier cb)
            {
                bw.Write((byte)(cb.point1.X));
                bw.Write((byte)(cb.point2.X));
                bw.Write((byte)(cb.point1.Y));
                bw.Write((byte)(cb.point2.Y));
            }

        }

        /////////////////////////////////////////////////////////////////////////////////////////////////

        /// <summary>
        /// 照明レコードの情報を格納するクラス
        /// </summary>
        public class LightRecord : Record
        {

            public LightRecord() { }

            /// <summary>
            /// インスタンスの作成と同時にデータを読み出す
            /// </summary>
            public LightRecord(Stream stream)
            {
                this.Read(stream);
            }

            /// <summary>
            /// クラスの複製
            /// </summary>
            public override object Clone()
            {
                //値型しか持たないのでMemberwiseCloneで済ませる
                return this.MemberwiseClone();
            }

            /// <summary>
            /// 赤色要素 (0.0 to 1.0)
            /// </summary>
            public float R = 154f / 255f;
            /// <summary>
            /// 緑色要素 (0.0 to 1.0)
            /// </summary>
            public float G = 154f / 255f;
            /// <summary>
            /// 青色要素 (0.0 to 1.0)
            /// </summary>
            public float B = 154f / 255f;

            /// <summary>
            /// 照射方向の情報 (-1.0 to 1.0)
            /// </summary>
            public Transfer Dir = Transfer.GetDefault();


            /// <summary>
            /// ファイル書き込み時のデータ長
            /// </summary>
            public static int DataLength { get { return 28; } }

            /// <summary>
            /// ストリームから単独のレコードを読み出す
            /// </summary>
            public override void Read(Stream stream)
            {
                BinaryReader br = new BinaryReader(stream);

                this.FrameNumber = br.ReadInt32();
                this.R = br.ReadSingle();
                this.G = br.ReadSingle();
                this.B = br.ReadSingle();
                this.Dir.x = br.ReadSingle();
                this.Dir.y = br.ReadSingle();
                this.Dir.z = br.ReadSingle();


            }

            /// <summary>
            /// ストリームに単独のレコードを書き出す
            /// </summary>
            public override void Write(Stream stream)
            {
                BinaryWriter bw = new BinaryWriter(stream);

                bw.Write(this.FrameNumber);
                bw.Write(this.R);
                bw.Write(this.G);
                bw.Write(this.B);
                bw.Write(this.Dir.x);
                bw.Write(this.Dir.y);
                bw.Write(this.Dir.z);

            }


        }

        /////////////////////////////////////////////////////////////////////////////////////////////////

        /// <summary>
        /// 照明レコードの情報を格納するクラス
        /// </summary>
        public class ShadowRecord : Record
        {

            public ShadowRecord() { }

            /// <summary>
            /// インスタンスの作成と同時にデータを読み出す
            /// </summary>
            public ShadowRecord(Stream stream)
            {
                this.Read(stream);
            }

            /// <summary>
            /// クラスの複製
            /// </summary>
            public override object Clone()
            {
                //値型しか持たないのでMemberwiseCloneで済ませる
                return this.MemberwiseClone();
            }

            /// <summary>
            /// モード(0-2)
            /// </summary>
            public byte mode = 0;
            /// <summary>
            /// 距離 (0.1 - (dist * 0.00001))
            /// </summary>
            public float Distance = 0.1f;



            /// <summary>
            /// ファイル書き込み時のデータ長
            /// </summary>
            public static int DataLength { get { return 9; } }

            /// <summary>
            /// ストリームから単独のレコードを読み出す
            /// </summary>
            public override void Read(Stream stream)
            {
                BinaryReader br = new BinaryReader(stream);

                this.FrameNumber = br.ReadInt32();
                this.mode = br.ReadByte();
                this.Distance = br.ReadSingle();

            }

            /// <summary>
            /// ストリームに単独のレコードを書き出す
            /// </summary>
            public override void Write(Stream stream)
            {
                BinaryWriter bw = new BinaryWriter(stream);

                bw.Write(this.FrameNumber);
                bw.Write(this.mode);
                bw.Write(this.Distance);

            }


        }

        /////////////////////////////////////////////////////////////////////////////////////////////////





        // ツール的関数群 ////////////////

        //ストリームからShift-JIS形式の文字列を読み取る
        //ByteSizeを指定すると、その分だけ読み取る
        //ByteSizeにゼロを指定すると、0x00が出現するまで読み取る
        static private string StreamRead_ShiftJIS(Stream stream, int ByteSize)
        {
            Encoding Shift_JIS = Encoding.GetEncoding(932);
            MemoryStream buf1 = new MemoryStream();
            string retstr;

            int i = 0, val;

            while (!(ByteSize > 0 && i >= ByteSize)) //指定バイト数読み取ったら終了
            {
                val = stream.ReadByte();
                i++;

                if (val == 0x00) //終端コードを検出
                {
                    if (ByteSize > 0) stream.Seek(ByteSize - i, SeekOrigin.Current);
                    break;
                }

                buf1.WriteByte((byte)val);

            }

            buf1.Position = 0;
            StreamReader sr = new StreamReader(buf1, Shift_JIS, false);
            retstr = sr.ReadToEnd();
            sr.Close();

            return retstr;
        }

        static private void StreamWrite_ShiftJIS(Stream stream, string str, int ByteSize)
        {
            Encoding Shift_JIS = Encoding.GetEncoding(932);
            MemoryStream buf1 = new MemoryStream();

            StreamWriter sw = new StreamWriter(buf1, Shift_JIS);
            sw.AutoFlush = true;
            sw.Write(str);

            while (buf1.Length < ByteSize) buf1.WriteByte(0);
            buf1.Position = 0;
            for (int i = 0; i < ByteSize; i++) stream.WriteByte((byte)buf1.ReadByte());

            sw.Close();

        }







    }


    /////////////////////////////////////////////////////////////////////////////////////////////////

    //　基礎的な構造体の定義　///////////////////////////////////////////////////////////////////////

    /////////////////////////////////////////////////////////////////////////////////////////////////


    /// <summary>
    /// 補完ベジエ曲線の情報を格納する構造体の定義
    /// </summary>
    public struct ComplementBezier
    {
        //0-127の整数座標
        public Point point1;

        //0-127の整数座標
        public Point point2;

        public static ComplementBezier GetDefault()
        {
            ComplementBezier def = new ComplementBezier();
            def.point1.X = 20;
            def.point1.Y = 20;
            def.point2.X = 107;
            def.point2.Y = 107;
            return def;
        }

        /// <summary>
        /// 4つの要素をカンマで結合して文字列に
        /// </summary>
        public override string ToString()
        {
            return point1.X.ToString() + "," + point1.Y.ToString() + "," + point2.X.ToString() + "," + point2.Y.ToString();
        }

        /// <summary>
        /// カンマ区切りの4つの数字の文字列から値の受け入れ
        /// </summary>
        public bool FromString(string str)
        {
            string[] strs = str.Split(',');

            if (strs.Length != 4) throw new Exception("Can't convert to ComplementBezier.");

            this.point1.X = int.Parse(strs[0]);
            this.point1.Y = int.Parse(strs[1]);
            this.point2.X = int.Parse(strs[2]);
            this.point2.Y = int.Parse(strs[3]);

            return true;
        }


        /// <summary>
        /// 補完曲線から補完の値を取得
        /// </summary>
        /// <param name="x">0から1.0の実数</param>
        public float GetComplementValue(float x)
        {
            //上手くXY関数に落とし込む方法が分からなかったので強引に漸近させて解いています
            //たぶんかなり遅いです
            int i;
            float t = 0.5f;
            float dt = 0.5f;
            pointf_ex[] p = new pointf_ex[10];

            if (x < 0) x = 0;
            if (x > 1) x = 0;

            p[0] = new pointf_ex(0, 0);
            p[1] = new pointf_ex(point1.X / 127f, point1.Y / 127f);
            p[2] = new pointf_ex(point2.X / 127f, point2.Y / 127f);
            p[3] = new pointf_ex(1, 1);

            for (i = 0; i < 14; i++)
            {
                p[4] = p[0] * t + p[1] * (1 - t);
                p[5] = p[1] * t + p[2] * (1 - t);
                p[6] = p[2] * t + p[3] * (1 - t);

                p[7] = p[4] * t + p[5] * (1 - t);
                p[8] = p[5] * t + p[6] * (1 - t);

                p[9] = p[7] * t + p[8] * (1 - t);

                dt /= 2;
                if (p[9].X > x) t += dt; else t -= dt;

            }

            return p[9].Y;
        }

        //成分ごとに書くのが面倒なので、演算子のオーバーロードで一気に処理させる
        private struct pointf_ex
        {
            public pointf_ex(float X, float Y)
            {
                this.X = X; this.Y = Y;
            }

            public float X;
            public float Y;

            public static pointf_ex operator *(pointf_ex pfex, float t)
            {
                pfex.X *= t; pfex.Y *= t;
                return pfex;
            }

            public static pointf_ex operator +(pointf_ex pfex1, pointf_ex pfex2)
            {
                pfex1.X += pfex2.X; pfex1.Y += pfex2.Y;
                return pfex1;
            }
        }
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////


    /// <summary>
    /// 平行移動の情報を格納する構造体の定義
    /// </summary>
    public struct Transfer
    {
        public float x;
        public float y;
        public float z;

        /// <summary>
        /// 要素を指定して新しいインスタンスを作成します
        /// </summary>
        public Transfer(float x, float y, float z)
        {
            this.x = x;
            this.y = y;
            this.z = z;

        }

        /// <summary>
        /// 初期値を取得
        /// </summary>
        public static Transfer GetDefault()
        {
            Transfer def;
            def.x = def.y = def.z = 0;
            return def;
        }

        /// <summary>
        /// 要素同士の加算
        /// </summary>
        public static Transfer operator +(Transfer u, Transfer v)
        {
            u.x += v.x; u.y += v.y; u.z += v.z;
            return u;
        }

        /// <summary>
        /// 要素同士の減算
        /// </summary>
        public static Transfer operator -(Transfer u, Transfer v)
        {
            u.x -= v.x; u.y -= v.y; u.z -= v.z;
            return u;
        }


        /// <summary>
        /// クオータニオンによる座標変換
        /// </summary>
        public Transfer RotByQuaternion(Quaternion Qt)
        {
            Transfer u = this;

            Quaternion qt1 = new Quaternion();
            qt1.x = u.x; qt1.y = u.y; qt1.z = u.z;
            qt1.w = 0;

            qt1 = ((!Qt) * qt1) * Qt;
            u.x = qt1.x; u.y = qt1.y; u.z = qt1.z;

            return u;
        }

        /// <summary>
        /// クオータニオンによる座標変換
        /// </summary>
        public static Transfer operator *(Transfer u, Quaternion v)
        {
            return u.RotByQuaternion(v);
        }

        /// <summary>
        /// 2つの移動量の間の補完した値を返す
        /// </summary>
        public static Transfer Complement(Transfer u, Transfer v, float tx, float ty, float tz)
        {
            u.x += (v.x - u.x) * tx;
            u.y += (v.y - u.y) * ty;
            u.z += (v.z - u.z) * tz;
            return u;
        }

        /// <summary>
        /// 3つの要素をカンマで結合して表示
        /// </summary>
        public override string ToString()
        {
            return x.ToString() + "," + y.ToString() + "," + z.ToString();
        }

        /// <summary>
        /// フォーマットを指定して3つの要素をカンマで結合して表示
        /// </summary>
        public string ToString(string format)
        {
            return x.ToString(format) + "," + y.ToString(format) + "," + z.ToString(format);
        }
    }


    /////////////////////////////////////////////////////////////////////////////////////////////////


    /// <summary>
    /// ボーンの回転の情報を格納する構造体の定義 (クオータニオン)
    /// </summary>
    public struct Quaternion
    {
        public float x;
        public float y;
        public float z;
        public float w;

        /// <summary>
        /// オイラー角からクオータニオンを生成
        /// </summary>
        public Quaternion(EulerAngle eulerangle)
        {
            this = eulerangle.ToQuaternion();
        }
        /// <summary>
        /// オイラー角からクオータニオンを生成
        /// </summary>
        public Quaternion(float Xd, float Yd, float Zd)
        {
            EulerAngle ea = new EulerAngle();
            ea.Xd = Xd;
            ea.Yd = Yd;
            ea.Zd = Zd;
            this = ea.ToQuaternion();
        }

        /// <summary>
        /// 初期値を取得
        /// </summary>
        public static Quaternion GetDefault()
        {
            Quaternion def;
            def.x = 0;
            def.y = 0;
            def.z = 0;
            def.w = 1;
            return def;
        }

        /// <summary>
        /// 1回転のクオータニオン
        /// </summary>
        private static Quaternion GetFullQt()
        {
            Quaternion def;
            def.x = 0;
            def.y = 0;
            def.z = 0;
            def.w = -1;
            return def;
        }

        /// <summary>
        /// クオータニオンどうしの掛け算を行う
        /// </summary>
        public static Quaternion Multiply(Quaternion Qt1, Quaternion Qt2)
        {
            Quaternion Qret = new Quaternion();

            Qret.w = (Qt1.w * Qt2.w) - (Qt1.x * Qt2.x + Qt1.y * Qt2.y + Qt1.z * Qt2.z);
            Qret.x = (Qt1.w * Qt2.x) + (Qt2.w * Qt1.x) - (Qt1.y * Qt2.z - Qt1.z * Qt2.y);
            Qret.y = (Qt1.w * Qt2.y) + (Qt2.w * Qt1.y) - (Qt1.z * Qt2.x - Qt1.x * Qt2.z);
            Qret.z = (Qt1.w * Qt2.z) + (Qt2.w * Qt1.z) - (Qt1.x * Qt2.y - Qt1.y * Qt2.x);

            return Qret;
        }

        /// <summary>
        /// クオータニオンどうしの掛け算を行う
        /// </summary>
        public Quaternion Multiply(Quaternion Qt)
        {
            return Multiply(this, Qt);
        }

        /// <summary>
        /// 共役なクオータニオンを返す
        /// </summary>
        public static Quaternion Conjugate(Quaternion Qt)
        {
            Quaternion Qret = new Quaternion();

            Qret.w = Qt.w;
            Qret.x = -Qt.x;
            Qret.y = -Qt.y;
            Qret.z = -Qt.z;

            return Qret;
        }

        /// <summary>
        /// 共役なクオータニオンを返す
        /// </summary>
        public Quaternion Conjugate()
        {
            return Conjugate(this);
        }

        /// <summary>
        /// wが正のクオータニオンを返す
        /// </summary>
        public Quaternion Positive()
        {
            if (w > 0) return this;
            else return this * GetFullQt();
        }

        /// <summary>
        /// wが負のクオータニオンを返す
        /// </summary>
        public Quaternion Negative()
        {
            if (w < 0) return this;
            else return this * GetFullQt();
        }

        /// <summary>
        /// クオータニオンの大きさを取得
        /// </summary>
        public float Length
        {
            get
            {
                return (float)Math.Sqrt(w * w + x * x + y * y + z * z);
            }
        }

        /// <summary>
        /// クオータニオンを正規化
        /// </summary>
        public Quaternion Normalize()
        {
            Quaternion qt1 = new Quaternion();
            float l1 = this.Length;
            qt1.w = this.w / l1;
            qt1.x = this.x / l1;
            qt1.y = this.y / l1;
            qt1.z = this.z / l1;
            return qt1;

        }

        //軸周りの回転量をラジアンで返す
        public float RotAngle
        {
            get
            {
                return ((float)(Math.Acos(this.w) * 2.0));
            }
        }

        /// <summary>
        /// クオータニオン同士の掛け算の演算子のオーバーロード
        /// </summary>
        public static Quaternion operator *(Quaternion z, Quaternion w)
        {
            return Multiply(z, w);
        }

        /// <summary>
        /// クオータニオンの回転量を実数倍
        /// </summary>
        public static Quaternion operator *(Quaternion q, float t)
        {
            q = q.Normalize();
            double halfangle = Math.Acos(q.w);
            if (halfangle == 0.0) //ゼロ回転はそのまま返す
            {
                return q;
            }
            float sinrate = (float)(Math.Sin(halfangle * t) / Math.Sin(halfangle));
            q.w = (float)Math.Cos(halfangle * t);
            q.x *= sinrate;
            q.y *= sinrate;
            q.z *= sinrate;
            return q;
        }

        /// <summary>
        /// !演算子を共役に割り当て
        /// </summary>
        public static Quaternion operator !(Quaternion x)
        {
            return Conjugate(x);
        }


        /// <summary>
        /// クオータニオンをオイラー角に変換(ZXY)
        /// </summary>
        public EulerAngle ToEulerAngle()
        {
            EulerAngle ea = EulerAngle.GetDefault();

            double xx = 1f - 2 * y * y - 2 * z * z;
            double xy = 2 * x * y - 2 * z * w;
            double xz = 2 * x * z + 2 * y * w;

            double yx = 2 * x * y + 2 * z * w;
            double yy = 1f - 2 * x * x - 2 * z * z;
            double yz = 2 * y * z - 2 * x * w;

            double zx = 2 * x * z - 2 * y * w;
            double zy = 2 * y * z + 2 * x * w;
            double zz = 1f - 2 * x * x - 2 * y * y;

            ea.x = -(float)Math.Asin(yz);

            if (Math.Abs(Math.Cos(ea.x)) < 0.001)
            {
                ea.z = (float)Math.Atan2(xy, xx);
                ea.y = 0;
            }
            else
            {
                ea.z = (float)Math.Atan2(yx, yy);
                ea.y = (float)Math.Asin(xz / Math.Cos(ea.x));
                if (zz < 0) ea.y = (float)Math.PI - ea.y;
            }



            if (ea.x > Math.PI) ea.x = -2 * (float)Math.PI + ea.x;
            if (ea.y > Math.PI) ea.y = -2 * (float)Math.PI + ea.y;
            if (ea.z > Math.PI) ea.z = -2 * (float)Math.PI + ea.z;
            if (ea.x < -Math.PI) ea.x = 2 * (float)Math.PI + ea.x;
            if (ea.y < -Math.PI) ea.y = 2 * (float)Math.PI + ea.y;
            if (ea.z < -Math.PI) ea.z = 2 * (float)Math.PI + ea.z;

            /*int n = 0;

            if (ea.Xd == 180) n++;
            if (ea.Yd == 180) n++;
            if (ea.Zd == 180) n++;

            if (n == 2)
            {
                if (ea.Xd == 180) ea.Xd = 0;
                if (ea.Yd == 180) ea.Yd = 0;
                if (ea.Zd == 180) ea.Zd = 0;

            }*/

            return ea;
        }



        /// <summary>
        /// 2つのクオータニオンの間の補完した値を返す
        /// </summary>
        public static Quaternion Complement(Quaternion u, Quaternion v, float t)
        {
            Quaternion d = v * (!u); //差分クオータニオン
            d = d.Positive();
            Quaternion r = u * (d * t);
            if (float.IsNaN(r.w))
            {
                
                System.Diagnostics.Debugger.Break();
            }
            return r;
            //return u * (d.Positive() * t);
        }


        /// <summary>
        /// 4つの要素をカンマで結合して返す
        /// </summary>
        public override string ToString()
        {
            return x.ToString() + "," + y.ToString() + "," + z.ToString() + "," + w.ToString();
        }

        /// <summary>
        /// フォーマットを指定して4つの要素をカンマで結合して返す
        /// </summary>
        public string ToString(string format)
        {
            return x.ToString(format) + "," + y.ToString(format) + "," + z.ToString(format) + "," + w.ToString(format);
        }
    }


    /////////////////////////////////////////////////////////////////////////////////////////////////


    /// <summary>
    /// オイラー角による回転の情報を格納する構造体の定義
    /// </summary>
    public struct EulerAngle
    {
        public float x; //X軸回りの回転
        public float y; //Y軸回りの回転
        public float z; //Z軸回りの回転

        /// <summary>
        /// Degreeによる回転角度
        /// </summary>
        public float Xd
        {
            get { return RadToDeg(x); }
            set { x = DegToRad(value); }
        }

        /// <summary>
        /// Degreeによる回転角度
        /// </summary>
        public float Yd
        {
            get { return RadToDeg(y); }
            set { y = DegToRad(value); }
        }

        /// <summary>
        /// Degreeによる回転角度
        /// </summary>
        public float Zd
        {
            get { return RadToDeg(z); }
            set { z = DegToRad(value); }
        }

        /// <summary>
        /// 初期値を取得
        /// </summary>
        public static EulerAngle GetDefault()
        {
            EulerAngle def;
            def.x = 0;
            def.y = 0;
            def.z = 0;
            return def;
        }

        /// <summary>
        /// オイラー角をクオータニオンに変換(ZXY)
        /// </summary>
        public Quaternion ToQuaternion()
        {

            Quaternion qx = Quaternion.GetDefault();
            Quaternion qy = Quaternion.GetDefault();
            Quaternion qz = Quaternion.GetDefault();

            //それぞれの単独の軸回りの回転のクオータニオンを作成し、合成
            qx.x = (float)Math.Sin(this.x / 2);
            qx.w = (float)Math.Cos(this.x / 2);
            qy.y = (float)Math.Sin(this.y / 2);
            qy.w = (float)Math.Cos(this.y / 2);
            qz.z = (float)Math.Sin(this.z / 2);
            qz.w = (float)Math.Cos(this.z / 2);

            return qz * qx * qy;
        }


        /// <summary>
        /// 度をラジアンに変換
        /// </summary>
        public static float DegToRad(float x)
        {
            return (float)(x * Math.PI / 180.0);
        }
        /// <summary>
        /// ラジアンを度に変換
        /// </summary>
        public static float RadToDeg(float x)
        {
            float y = (float)(x * 180.0 / Math.PI);
            if (y > 0) return (int)(y * 1000 + 0.5f) / 1000f; //下3桁で四捨五入
            else return (int)(y * 1000 - 0.5f) / 1000f; //下3桁で四捨五入
        }

        /// <summary>
        /// 3つの要素をカンマで結合してdegreeで表示:主にデバッグ用
        /// </summary>
        public override string ToString()
        {
            return Xd.ToString() + "," + Yd.ToString() + "," + Zd.ToString();
        }

    }

}
