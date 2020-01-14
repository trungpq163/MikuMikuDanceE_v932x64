
/***************************************************************
 * 
 * Ver.1.2
 * 
 * MMTの中核処理の部分です
 * UI部分は汚くて恥ずかしいので未公開。
 * まあこれもそうとう汚いですが。
 * 何かに使いたい人はお好きにどうぞ
 * 
 * バグ盛りだくさんでも気にしない
 * 
 * ***************************************************************/

using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;


namespace MikuMikuTelop
{

    class MMTSystem
    {

        public MMTSystem()
        {
            CreateSystemCommandTable();
        }

        /// <summary>
        /// 書式などの情報
        /// </summary>
        public class MMTStatus : ICloneable
        {
            public enum HAlign
            {
                left,
                center,
                right,
            }

            public enum VAlign
            {
                top,
                center,
                bottom,
            }

            public SizeF Screen = new SizeF(1280, 720);

            public float ScreenAspect { get { return Screen.Width / Screen.Height; } }

            public string FontName = "ＭＳ ゴシック";
            public float FontSize = 12;

            public bool Bold = false;
            public bool Italic = false;
            public bool Underline = false;
            public bool Strikeout = false;

            public PointF Position = new PointF(-94, -79);
            public float Z = 0;

            public Color FontColor = Color.FromArgb(255, 255, 255);

            public Color EdgeColor = Color.FromArgb(0, 0, 0);
            public float EdgeBold = 6;
            public bool EdgeRound = false;

            public Color ShadowColor = Color.FromArgb(0, 0, 100);
            public float ShadowDistance = 0;
            public float ShadowBlur = 0;

            public float Alpha = 1.0f;

            public float AutoTime = 0.3f;
            public float Fade = 0.5f;

            public HAlign hAlign = HAlign.left;
            public VAlign vAlign = VAlign.bottom;

            public bool NextSkip = false;

            public SizeF Margin = new SizeF(5, 5);
            public Color BackColor = Color.FromArgb(0, 255, 255, 255);

            public bool Tate = false;
            public bool BillBoard = false;

            public object Clone()
            {
                MMTStatus st = (MMTStatus)this.MemberwiseClone();

                return st;
            }
        }


        public class TelopData
        {
            public MMTStatus status;

            public float StartTime = 0;
            public float EndTime = 0;

            public Bitmap Texture;
            public string TextureName = "";
            public Size TextureSize = new Size();

            public string Text = "";

        }

        /// <summary>
        /// スクリプト解析結果の出力クラス
        /// </summary>
        public class MMTOut
        {
            public TelopData[] Telops = null;
            public string Effect = "";
        }

        /// <summary>
        /// 現在のステータス
        /// </summary>
        public MMTStatus Status = new MMTStatus();

        /// <summary>
        /// テクスチャの作成を抑制します。
        /// </summary>
        public bool NoTextureCreate = false;


        #region Gaussian Blur

        /// <summary>
        /// ガウスぼかし
        /// </summary>
        /// <param name="bmp"></param>
        private void Gaussian(ref Bitmap bmp, int ext)
        {
            int wi = bmp.Width;
            int hi = bmp.Height;

            BitmapData bmpdata = bmp.LockBits(new Rectangle(0, 0, wi, hi), ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);

            byte[] buf1 = new byte[wi * hi * 4];
            byte[] buf2 = new byte[wi * hi * 4];

            int stride = bmpdata.Stride;
            IntPtr Scan0 = bmpdata.Scan0;

            int i, j, x, y;

            for (y = 0; y < hi; ++y)
            {
                IntPtr src_line = (IntPtr)((Int64)Scan0 + y * stride);
                Marshal.Copy(src_line, buf1, y * wi * 4, wi * 4);
            }

            double[] e_table = new double[ext * 2 + 1];

            //正規分布テーブル
            for (i = -ext; i <= ext; i++)
            {
                double e = (double)i / (ext / 2.0);
                e_table[i + ext] = Math.Exp(-e * e / 2.0);
            }

            for (y = 0; y < hi; y++)
            {
                for (x = 0; x < wi; x++)
                {
                    double e, n = 0, n2 = 0;
                    double a = 0, r = 0, g = 0, b = 0;

                    for (i = -ext; i <= ext; i++)
                    {
                        e = e_table[i + ext];

                        j = x + i;
                        if (0 <= j && j < wi)
                        {
                            j = (j + y * wi) * 4;

                            a += buf1[j + 3] * e;
                            n += e;

                            e *= buf1[j + 3] / 255.0;

                            r += buf1[j + 2] * e;
                            g += buf1[j + 1] * e;
                            b += buf1[j + 0] * e;
                            n2 += e;

                        }

                        if (n2 > 0)
                        {
                            j = (x + y * wi) * 4;
                            buf2[j + 3] = (byte)(a / n);
                            buf2[j + 2] = (byte)(r / n2);
                            buf2[j + 1] = (byte)(g / n2);
                            buf2[j + 0] = (byte)(b / n2);
                        }
                    }

                }
            }

            for (y = 0; y < hi; y++)
            {
                for (x = 0; x < wi; x++)
                {
                    double e, n = 0, n2 = 0;
                    double a = 0, r = 0, g = 0, b = 0;

                    for (i = -ext; i <= ext; i++)
                    {
                        e = e_table[i + ext];

                        j = y + i;
                        if (0 <= j && j < hi)
                        {
                            j = (x + j * wi) * 4;

                            a += buf2[j + 3] * e;
                            n += e;

                            e *= buf2[j + 3] / 255.0;

                            r += buf2[j + 2] * e;
                            g += buf2[j + 1] * e;
                            b += buf2[j + 0] * e;
                            n2 += e;

                        }

                        if (n2 > 0)
                        {
                            j = (x + y * wi) * 4;
                            buf1[j + 3] = (byte)(a / n);
                            buf1[j + 2] = (byte)(r / n2);
                            buf1[j + 1] = (byte)(g / n2);
                            buf1[j + 0] = (byte)(b / n2);
                        }
                    }

                }
            }

            for (y = 0; y < hi; ++y)
            {
                IntPtr dst_line = (IntPtr)((Int64)Scan0 + y * stride);
                Marshal.Copy(buf1, y * wi * 4, dst_line, wi * 4);
            }

            bmp.UnlockBits(bmpdata);

        }

        #endregion

        /// <summary>
        /// 行の反転
        /// </summary>
        /// <param name="str"></param>
        /// <returns></returns>
        string ReverseLine(string str)
        {
            string[] strs = str.Replace(Environment.NewLine, "\n").Split('\n');

            for (int i = 0; i < strs.Length / 2; i++)
            {
                int i2 = strs.Length - 1 - i;
                string s1 = strs[i];
                strs[i] = strs[i2];
                strs[i2] = s1;
            }

            return String.Join(Environment.NewLine, strs);
        }

        public Bitmap CreateTextTexture(string Text)
        {
            Size dummy;
            return CreateTextTexture(Text, out dummy);
        }

        /// <summary>
        /// 字幕テクスチャの描画
        /// </summary>
        /// <param name="Text"></param>
        /// <returns></returns>
        public Bitmap CreateTextTexture(string Text, out Size TexSize)
        {
            FontStyle style = FontStyle.Regular;

            if (Status.Bold) style |= FontStyle.Bold;
            if (Status.Italic) style |= FontStyle.Italic;
            if (Status.Underline) style |= FontStyle.Underline;
            if (Status.Strikeout) style |= FontStyle.Strikeout;


            float fsizepx = Status.Screen.Height * Status.FontSize / 200.0f;
            Font font = new Font(Status.FontName, fsizepx, style, GraphicsUnit.Pixel);

            StringFormat sf = new StringFormat();

            if (Status.Tate)
            {
                sf.FormatFlags |= StringFormatFlags.DirectionVertical;
                Text = ReverseLine(Text);
            }
            else
            {
                sf.FormatFlags &= ~StringFormatFlags.DirectionVertical;
            }

            Bitmap bmpdmy = new Bitmap(16, 16);
            Graphics g1 = Graphics.FromImage(bmpdmy);

            SizeF size = g1.MeasureString(Text, font, new PointF(), sf);

            TexSize = new Size();
            TexSize.Width = (int)(size.Width + fsizepx * Status.Margin.Width / 50.0f);
            TexSize.Height = (int)(size.Height + fsizepx * Status.Margin.Height / 50.0f);

            if (this.NoTextureCreate) return null;

            Bitmap bmp = new Bitmap(TexSize.Width, TexSize.Height,  PixelFormat.Format32bppArgb);
            Graphics g = Graphics.FromImage(bmp);

            PointF p1 = new PointF(fsizepx * Status.Margin.Width / 100.0f, fsizepx * Status.Margin.Height / 100.0f);

            System.Drawing.Drawing2D.GraphicsPath gp;

            g.Clear(Status.BackColor);

            g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.HighQuality;
            g.CompositingQuality = System.Drawing.Drawing2D.CompositingQuality.HighQuality;

            MMTStatus.HAlign hal = Status.hAlign;
            MMTStatus.VAlign val = Status.vAlign;
            //if (Status.Tate) hal = 2 - hal;

            if (!Status.Tate)
            {
                if (hal == MMTStatus.HAlign.right)
                {
                    sf.Alignment = StringAlignment.Far;
                    p1.X = bmp.Width - p1.X;
                }
                else if (hal == MMTStatus.HAlign.center)
                {
                    sf.Alignment = StringAlignment.Center;
                    p1.X = bmp.Width / 2;
                }
                else if (hal == MMTStatus.HAlign.left)
                {
                    sf.Alignment = StringAlignment.Near;
                }
            }
            else
            {
                if (val == MMTStatus.VAlign.bottom)
                {
                    sf.Alignment = StringAlignment.Far;
                    p1.Y = bmp.Height - p1.Y;
                }
                else if (val == MMTStatus.VAlign.center)
                {
                    sf.Alignment = StringAlignment.Center;
                    p1.Y = bmp.Height / 2;
                }
                else if (val == MMTStatus.VAlign.top)
                {
                    sf.Alignment = StringAlignment.Near;
                }
            }

            bool sdw = Status.ShadowDistance > 0;
            bool edg = Status.EdgeBold > 0;
            bool blr = Status.ShadowBlur > 0;

            if (sdw)
            {
                gp = new System.Drawing.Drawing2D.GraphicsPath();

                float f = fsizepx * (Status.ShadowDistance / 100);
                PointF p2 = p1;
                p2.X += f;
                p2.Y += f;
                gp.AddString(Text, font.FontFamily, (int)font.Style, fsizepx, p2, sf);

                Brush brush_shadow = new SolidBrush(Status.ShadowColor);
                g.FillPath(brush_shadow, gp);
            }

            gp = new System.Drawing.Drawing2D.GraphicsPath();

            gp.AddString(Text, font.FontFamily, (int)font.Style, fsizepx, p1, sf);

            if (edg)
            {
                Pen pen = new Pen(Status.EdgeColor, fsizepx * Status.EdgeBold * 2 / 100);

                if (Status.EdgeRound)
                {
                    pen.StartCap = System.Drawing.Drawing2D.LineCap.Round;
                    pen.EndCap = System.Drawing.Drawing2D.LineCap.Round;
                    pen.LineJoin = System.Drawing.Drawing2D.LineJoin.Round;
                }
                else
                {
                    pen.LineJoin = System.Drawing.Drawing2D.LineJoin.MiterClipped;
                    pen.MiterLimit = 3;
                }
                
                g.DrawPath(pen, gp);
            }

            if ((sdw || edg) && blr)
            {
                int ext = (int)(fsizepx * Status.ShadowBlur / 100);
                Gaussian(ref bmp, ext);
            }

            Brush brush = new SolidBrush(Status.FontColor);
            g.FillPath(brush, gp);

            return bmp;

        }



        /// <summary>
        /// 時間文字列の解析
        /// </summary>
        /// <param name="text"></param>
        /// <returns></returns>
        float TimeParse(string text)
        {
            bool frame = false;
            float val;

            text = text.Trim();

            if (text.EndsWith("F", StringComparison.InvariantCultureIgnoreCase))
            {
                frame = true;
                text = text.Substring(0, text.Length - 1);
            }

            val = float.Parse(text);

            if (frame) val /= 30;

            return val;
        }

        /// <summary>
        /// テキストコマンドの解析
        /// </summary>
        /// <param name="cmd"></param>
        /// <param name="StartTime"></param>
        /// <param name="EndTime"></param>
        void TextCommandParse(string cmd, ref float StartTime, ref float EndTime)
        {
            cmd = cmd.Substring(1);

            string[] prms;
            bool endtimemode = (cmd.IndexOf('~') > 0);

            if (endtimemode) prms = cmd.Split('~');
            else prms = cmd.Split(',');
            
            string stt = prms[0].Trim();

            if (stt.StartsWith("+")) StartTime = EndTime + TimeParse(stt.Substring(1));
            else if (stt.StartsWith("*")) StartTime = StartTime + TimeParse(stt.Substring(1));
            else StartTime = TimeBase + TimeParse(stt);

            if (prms.Length == 1)
            {
                if(stt != "*0") EndTime = -1;
            }
            else if (prms.Length == 2)
            {
                if (endtimemode)
                {
                    EndTime = TimeParse(prms[1]);
                    if (StartTime > EndTime) throw new Exception("MMT:終了時刻が表示時刻より前です");
                }
                else
                {
                    EndTime = StartTime + TimeParse(prms[1]);
                }
            }
            else
            {
                throw new Exception("MMT:書式が正しくありません");

            }
        }


        private List<TelopData> teloplist = new List<TelopData>();
        private bool End = false;
        private Hashtable sets = new Hashtable();
        private float TimeBase = 0;

        public string ErrorMessage = "";

        /// <summary>
        /// スクリプトの解析
        /// </summary>
        /// <param name="MMTScript"></param>
        /// <param name="MMETemplate"></param>
        /// <returns></returns>
        public MMTOut Parse(string MMTScript, string MMETemplate)
        {
            
            MMTScript = MMTScript.Replace("\r\n", "\n");
            MMTScript = MMTScript.Replace("\r", "\n");

            string[] lines = MMTScript.Split('\n');

            int i, j, k = 0;

            StringBuilder Text = new StringBuilder();
            bool InTextCommand = false;
            float StartTime = 0, EndTime = 0;


            teloplist = new List<TelopData>();
            sets = new Hashtable();
            End = false;
            TimeBase = 0;

            this.Status = new MMTStatus();

            for (i = 0; i < lines.Length; i++)
            {
                try
                {
                    string line = lines[i];
                    string linetrimed = line.Replace('\t', ' ').Trim();

                    if (linetrimed == "")
                    {
                        if (InTextCommand) Text.Append(line + "\n");
                    }
                    else if (linetrimed.StartsWith("//"))
                    {

                    }
                    else if (linetrimed.StartsWith(":"))
                    {
                        string cmd;

                        if (InTextCommand)
                        {
                            DoTextCommand(Text.ToString(), ref StartTime, ref EndTime);
                            Text.Clear();
                            InTextCommand = false;
                        }

                        k = i;

                        j = linetrimed.IndexOf(' ');
                        if (j < 0)
                        {
                            cmd = linetrimed.Substring(1, linetrimed.Length - 1);
                            DoSystemCommandEx(cmd, null);
                        }
                        else
                        {
                            cmd = linetrimed.Substring(1, j - 1);
                            DoSystemCommandEx(cmd, linetrimed.Substring(j).Split(','));
                        }

                    }
                    else if (linetrimed.StartsWith("@") && !linetrimed.StartsWith("@@"))
                    {
                        if (InTextCommand)
                        {
                            DoTextCommand(Text.ToString(), ref StartTime, ref EndTime);
                            Text.Clear();
                            InTextCommand = false;
                        }

                        k = i;

                        TextCommandParse(linetrimed, ref StartTime, ref EndTime);

                        InTextCommand = true;
                    }
                    else
                    {
                        if (InTextCommand)
                        {
                            Text.Append(line.Replace("@@", "@") + "\n");
                        }
                        else
                        {
                            k = i;
                            throw new Exception();
                        }
                    }
                }
                catch (Exception e)
                {
                    k++;
                    ErrorMessage = "エラー： " + k.ToString() + "行";
                    if (e.Message.StartsWith("MMT:")) ErrorMessage += Environment.NewLine + e.Message.Substring(4);

                    return null;
                }

                if (End) break;
            }

            if (InTextCommand)
            {
                DoTextCommand(Text.ToString(), ref StartTime, ref EndTime);
                Text.Clear();
                InTextCommand = false;
            }


            MMTOut mmtout;

            try
            {
                mmtout = CreateMMTOut(MMETemplate);
            }
            catch
            {
                ErrorMessage = "エフェクトの作成に失敗しました";
                return null;
            }

            return mmtout;
        }

        /// <summary>
        /// テキストコマンドの実行
        /// </summary>
        /// <param name="Text"></param>
        /// <param name="StartTime"></param>
        /// <param name="EndTime"></param>
        private void DoTextCommand(string Text, ref float StartTime, ref float EndTime)
        {
            char[] spl = {'\n'};
            Text = Text.Trim(spl);

            if (Text == "") return;

            if (EndTime < 0) EndTime = Text.Length * Status.AutoTime + StartTime + Status.Fade * 2;
            
            if (Status.NextSkip)
            {
                Status.NextSkip = false;
                return;
            }

            Text = Text.Replace("\n", Environment.NewLine);

            TelopData ts = new TelopData();

            ts.status = (MMTStatus)Status.Clone();

            ts.StartTime = StartTime;
            ts.EndTime = EndTime;

            ts.Texture = CreateTextTexture(Text, out ts.TextureSize);
            ts.Text = Text;

            teloplist.Add(ts);

        }

        float fParseRange(string str, float min, float max)
        {
            float val = float.Parse(str);
            if (val < min || max < val) throw new Exception("MMT:パラメータ範囲外です");
            return val;
        }

        Color ColorParse(string[] strs)
        {
            Color color = new Color();

            if (strs.Length == 3)
            {
                color = Color.FromArgb(int.Parse(strs[0]), int.Parse(strs[1]), int.Parse(strs[2]));
            }
            else if (strs.Length == 4)
            {
                color = Color.FromArgb(int.Parse(strs[3]), int.Parse(strs[0]), int.Parse(strs[1]), int.Parse(strs[2]));
            }

            return color;
        }

        class SysCmd
        {
            public int ParamCount;
            public delegate void SystemCommandCall(string[] Params);
            public SystemCommandCall Call;

            public SysCmd(int paramcount, SystemCommandCall call)
            {
                ParamCount = paramcount;
                Call = call;
            }
        }

        Hashtable SystemCommandTable = new Hashtable();

        void CreateSystemCommandTable()
        {
            Hashtable sct = SystemCommandTable;

            sct.Add("font", new SysCmd(1, (string[] Params) => { Status.FontName = Params[0]; }));
            sct.Add("size", new SysCmd(1, (string[] Params) => { Status.FontSize = fParseRange(Params[0], 0.01f, 1000); }));
            sct.Add("fontcolor", new SysCmd(3, (string[] Params) => { Status.FontColor = ColorParse(Params); }));
            
            sct.Add("bold", new SysCmd(0, (string[] Params) => { Status.Bold = true; }));
            sct.Add("bold_off", new SysCmd(0, (string[] Params) => { Status.Bold = false; }));
            sct.Add("italic", new SysCmd(0, (string[] Params) => { Status.Italic = true; }));
            sct.Add("italic_off", new SysCmd(0, (string[] Params) => { Status.Italic = false; }));
            sct.Add("underline", new SysCmd(0, (string[] Params) => { Status.Underline = true; }));
            sct.Add("underline_off", new SysCmd(0, (string[] Params) => { Status.Underline = false; }));
            sct.Add("strikeout", new SysCmd(0, (string[] Params) => { Status.Strikeout = true; }));
            sct.Add("strikeout_off", new SysCmd(0, (string[] Params) => { Status.Strikeout = false; }));

            sct.Add("pos", new SysCmd(2, (string[] Params) => { Status.Position = new PointF(float.Parse(Params[0]), float.Parse(Params[1])); }));
            sct.Add("pos_x", new SysCmd(1, (string[] Params) => {
                if (Params[0].StartsWith("+")) Status.Position.X += float.Parse(Params[0].Substring(1));
                else Status.Position.X = float.Parse(Params[0]);
            }));
            sct.Add("pos_y", new SysCmd(1, (string[] Params) => {
                if (Params[0].StartsWith("+")) Status.Position.Y += float.Parse(Params[0].Substring(1));
                else Status.Position.Y = float.Parse(Params[0]);
            }));
            sct.Add("pos_z", new SysCmd(1, (string[] Params) => { Status.Z = float.Parse(Params[0]); }));

            sct.Add("pos_nextline", new SysCmd(0, (string[] Params) =>
            {
                TelopData tst = teloplist.Last();
                if (Status.vAlign != MMTStatus.VAlign.top || tst.status.vAlign != MMTStatus.VAlign.top) throw new Exception();
                Status.Position.Y = tst.status.Position.Y - (float)tst.TextureSize.Height * 200.0f / tst.status.Screen.Height;
                Status.Position.Y += tst.status.FontSize / 50.0f * tst.status.Margin.Height;
                Status.Position.Y += Status.FontSize / 50.0f * Status.Margin.Height;

            }));
            sct.Add("pos_next", new SysCmd(0, (string[] Params) =>
            {
                TelopData tst = teloplist.Last();
                if (Status.hAlign != MMTStatus.HAlign.left || tst.status.hAlign != MMTStatus.HAlign.left) throw new Exception();
                Status.Position.X = tst.status.Position.X + (float)tst.TextureSize.Width * 200.0f / tst.status.Screen.Width;
                Status.Position.X -= tst.status.FontSize / 50.0f * tst.status.Margin.Width / tst.status.ScreenAspect;
                Status.Position.X -= Status.FontSize / 50.0f * Status.Margin.Width / Status.ScreenAspect;

            }));

            sct.Add("align_left", new SysCmd(0, (string[] Params) => { Status.hAlign = MMTStatus.HAlign.left; }));
            sct.Add("align_center", new SysCmd(0, (string[] Params) => { Status.hAlign = MMTStatus.HAlign.center; }));
            sct.Add("align_right", new SysCmd(0, (string[] Params) => { Status.hAlign = MMTStatus.HAlign.right; }));

            sct.Add("valign_top", new SysCmd(0, (string[] Params) => { Status.vAlign = MMTStatus.VAlign.top; }));
            sct.Add("valign_center", new SysCmd(0, (string[] Params) => { Status.vAlign = MMTStatus.VAlign.center; }));
            sct.Add("valign_bottom", new SysCmd(0, (string[] Params) => { Status.vAlign = MMTStatus.VAlign.bottom; }));

            sct.Add("margin", new SysCmd(2, (string[] Params) => { Status.Margin = new SizeF(float.Parse(Params[0]), float.Parse(Params[1])); }));
            

            sct.Add("screen", new SysCmd(2, (string[] Params) => { Status.Screen = new SizeF(float.Parse(Params[0]), float.Parse(Params[1])); }));
            sct.Add("screen_height", new SysCmd(1, (string[] Params) => { Status.Screen.Height = float.Parse(Params[0]); }));

            sct.Add("edge", new SysCmd(1, (string[] Params) => { Status.EdgeBold = float.Parse(Params[0]); }));
            sct.Add("edgecolor", new SysCmd(3, (string[] Params) => { Status.EdgeColor = ColorParse(Params); }));
            sct.Add("edge_round", new SysCmd(0, (string[] Params) => { Status.EdgeRound = true; }));
            sct.Add("edge_round_off", new SysCmd(0, (string[] Params) => { Status.EdgeRound = true; }));

            sct.Add("shadow", new SysCmd(1, (string[] Params) => { Status.ShadowDistance = float.Parse(Params[0]); }));
            sct.Add("shadowcolor", new SysCmd(3, (string[] Params) => { Status.ShadowColor = ColorParse(Params); }));
            sct.Add("shadowblur", new SysCmd(1, (string[] Params) => { Status.ShadowBlur = float.Parse(Params[0]); }));

            sct.Add("alpha", new SysCmd(1, (string[] Params) => { Status.Alpha = fParseRange(Params[0], 0, 1); }));
            sct.Add("backcolor", new SysCmd(4, (string[] Params) => { Status.BackColor = ColorParse(Params); }));
            
            sct.Add("fade", new SysCmd(1, (string[] Params) => { Status.Fade = float.Parse(Params[0]); }));
            sct.Add("autotime", new SysCmd(1, (string[] Params) => { Status.AutoTime = TimeParse(Params[0]); }));
            sct.Add("timebase", new SysCmd(1, (string[] Params) => { this.TimeBase = TimeParse(Params[0]); }));

            sct.Add("tate", new SysCmd(0, (string[] Params) => { Status.Tate = true; }));
            sct.Add("tate_off", new SysCmd(0, (string[] Params) => { Status.Tate = false; }));

            sct.Add("billboard", new SysCmd(0, (string[] Params) => { Status.BillBoard = true; }));
            sct.Add("billboard_off", new SysCmd(0, (string[] Params) => { Status.BillBoard = false; }));

            sct.Add("set", new SysCmd(1, (string[] Params) => { sets.Add(Params[0], Status.Clone()); }));
            sct.Add("get", new SysCmd(1, (string[] Params) => {
                if (Params[0] == "default")
                {
                    Status = new MMTStatus();
                }
                else
                {
                    Status = (MMTStatus)((MMTStatus)sets[Params[0]]).Clone();
                }
            }));

            sct.Add("skip", new SysCmd(0, (string[] Params) => { Status.NextSkip = true; }));
            sct.Add("end", new SysCmd(0, (string[] Params) => { this.End = true; }));
            

        }

        /// <summary>
        /// システムコマンドの実行
        /// </summary>
        /// <param name="Command"></param>
        /// <param name="Params"></param>
        private void DoSystemCommandEx(string Command, string[] Params)
        {
            int i;

            if (Params != null)
            {
                for (i = 0; i < Params.Length; i++) Params[i] = Params[i].Trim();
            }

            Command = Command.Trim().ToLowerInvariant();

            SysCmd SystemCommand = (SysCmd)SystemCommandTable[Command];

            if (Params == null)
            {
                if (SystemCommand.ParamCount != 0) throw new Exception("MMT:パラメータの数が一致しません");
            }
            else if (SystemCommand.ParamCount != Params.Length)
            {
                throw new Exception("MMT:パラメータの数が一致しません");
            }

            SystemCommand.Call(Params);

        }



        string CutStringArea(ref string src, string areaName)
        {
            string str_areastart = "<<" + areaName + ">>";
            string str_areaend = "<<" + areaName + "End" + ">>";

            int areastart = src.IndexOf(str_areastart);
            int areaend = src.IndexOf(str_areaend);

            if (areastart < 0) return "";
            if (areaend < 0) return "";
            if (areaend <= areastart) return "";

            int areastart2 = areastart + str_areastart.Length;

            string cutarea = src.Substring(areastart2, areaend - areastart2);

            src = src.Substring(0, areastart2) + src.Substring(areaend + str_areaend.Length);

            return cutarea;
        }

        object[] CreateParamArray(int index, TelopData tst)
        {
            string texname = index.ToString() + ".png";
            float x = tst.status.Position.X / 100;
            float y = tst.status.Position.Y / 100;
            float z = tst.status.Z;
            float size = (float)tst.TextureSize.Height * 2 / tst.status.Screen.Height;
            float aspect = (float)tst.TextureSize.Width / (float)tst.TextureSize.Height;
            float stime = tst.StartTime;
            float etime = tst.EndTime;
            float fade = tst.status.Fade;
            float alpha = tst.status.Alpha;
            string billboard = tst.status.BillBoard.ToString().ToLowerInvariant();

            object[] ary = { index, texname, x, y, z, size, aspect, stime, etime, fade, alpha, billboard };

            return ary;
        }

        /// <summary>
        /// 出力の作成
        /// </summary>
        /// <param name="Template"></param>
        /// <returns></returns>
        MMTOut CreateMMTOut(string Template)
        {
            MMTOut mmtout = new MMTOut();
            int i, k;

            mmtout.Telops = new TelopData[teloplist.Count];

            for (i = 0; i < teloplist.Count; i++)
            {
                teloplist[i].TextureName = i.ToString() + ".png";
                mmtout.Telops[i] = teloplist[i];

            }

            string TexFmt = CutStringArea(ref Template, "Texture");
            string TecFmt = CutStringArea(ref Template, "Technique");
            string PassFmt = CutStringArea(ref TecFmt, "Pass");
            string PassSSFmt = CutStringArea(ref TecFmt, "PassSS");


            StringBuilder MMETextures = new StringBuilder();

            for (i = 0; i < teloplist.Count; i++)
            {
                MMETextures.AppendFormat(TexFmt, CreateParamArray(i, mmtout.Telops[i]));
            }

            Template = Template.Replace("<<Texture>>", MMETextures.ToString());


            StringBuilder[] MMETecs = new StringBuilder[9];
            StringBuilder[] MMETecsSS = new StringBuilder[9];

            for (k = 0; k < 9; k++)
            {
                MMETecs[k] = new StringBuilder();
                MMETecsSS[k] = new StringBuilder();
            }

            for (i = 0; i < teloplist.Count; i++)
            {
                k = (int)(teloplist[i].status.hAlign) * 3 + (int)(teloplist[i].status.vAlign);

                MMETecs[k].AppendFormat(PassFmt, CreateParamArray(i, mmtout.Telops[i]));
                MMETecsSS[k].AppendFormat(PassSSFmt, CreateParamArray(i, mmtout.Telops[i]));
                
            }

            StringBuilder MMETecMix = new StringBuilder();

            for (k = 0; k < 9; k++)
            {
                string tec = TecFmt.Replace("<<Align>>", k.ToString());

                tec = tec.Replace("<<Pass>>", MMETecs[k].ToString());
                tec = tec.Replace("<<PassSS>>", MMETecsSS[k].ToString());

                MMETecMix.Append(tec);

            }

            Template = Template.Replace("<<Technique>>", MMETecMix.ToString());

            mmtout.Effect = Template;

            return mmtout;
        }



    }

}
