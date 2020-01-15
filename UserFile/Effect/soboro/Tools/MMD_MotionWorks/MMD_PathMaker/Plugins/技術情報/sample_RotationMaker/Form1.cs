using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Text;
using System.IO;
using System.Windows.Forms;
using PathMakerPlugin;

namespace RotationMaker
{
    public partial class Form1 : Form
    {
        
        IPluginHost host;

        public Form1(IPluginHost Host)
        {
            host = Host;
            InitializeComponent();
        }

        private void Form1_Load(object sender, EventArgs e)
        {
            //自分自身のAssemblyを取得し、バージョンを返す
            System.Reflection.Assembly asm = System.Reflection.Assembly.GetExecutingAssembly();
            Version ver = asm.GetName().Version;

            //フォームタイトルにバージョン情報を表示
            Text += " " + ver.Major.ToString() + "." + ver.Minor.ToString();

            //ホストのフォームからアイコンを取得
            this.Icon = host.FormIcon;
        }

        private void button1_Click(object sender, EventArgs e)
        {
            
            try
            {
                VMDFormat vmd = new VMDFormat();
                
                //モデル名
                vmd.Actor = "回転メイカー";
                
                //回転軸
                Vector3D axis = new Vector3D(double.Parse(txtX.Text), double.Parse(txtY.Text), double.Parse(txtZ.Text));
                //回転係数
                double rotval = double.Parse(txtVal.Text);

                //軸を単位ベクトルに
                axis = axis.Normalize();

                //逆回転
                if (rotval <= 0)
                {
                    axis = axis * -1;
                    rotval = -rotval;
                }

                //ホストのプレビュー再生機能を開始
                if (host.Player.Start() == false)
                {
                    MessageBox.Show("正常な経路情報が取得できませんでした。", this.Text, MessageBoxButtons.OK, MessageBoxIcon.Exclamation);
                    return;
                }


                Transfer lastpos = host.Player.tr;
                Quaternion lastqt = host.Player.qt;

                //double Curvature = 0; //曲率

                double angle = 0, nextangle = 30;
                
                while (true)
                {
                    //モーションの最後
                    if (host.Player.NextFrame() == false)
                    {
                        double hrad = angle * Math.PI / 180;

                        VMDFormat.MotionRecord newmotion = new VMDFormat.MotionRecord();
                        newmotion.BoneName = txtBone.Text;
                        newmotion.FrameNumber = host.Player.Frame;

                        newmotion.Qt.w = (float)Math.Cos(hrad); //60度づつ回転
                        newmotion.Qt.x = (float)(axis.X * Math.Sin(hrad));
                        newmotion.Qt.y = (float)(axis.Y * Math.Sin(hrad));
                        newmotion.Qt.z = (float)(axis.Z * Math.Sin(hrad));

                        vmd.MotionRecords.Add(newmotion);

                        break;
                    }

                    Transfer dtr = host.Player.tr - lastpos;
                    double speed = Math.Sqrt(dtr.x * dtr.x + dtr.y * dtr.y + dtr.z * dtr.z); //[mmdd/f]

                    Quaternion dq = host.Player.qt * (!lastqt);
                    dq = dq.Positive().Normalize();

                    double angvel = dq.RotAngle; //[rad/f]

                    lastpos = host.Player.tr;
                    lastqt = host.Player.qt;


                    double da = speed * rotval;

                    angle += da;

                    if (angle >= nextangle)
                    {
                        double hrad = angle * Math.PI / 180;
                        
                        VMDFormat.MotionRecord newmotion = new VMDFormat.MotionRecord();
                        newmotion.BoneName = txtBone.Text;
                        newmotion.FrameNumber = host.Player.Frame;

                        newmotion.Qt.w = (float)Math.Cos(hrad); //60度づつ回転
                        newmotion.Qt.x = (float)(axis.X * Math.Sin(hrad));
                        newmotion.Qt.y = (float)(axis.Y * Math.Sin(hrad));
                        newmotion.Qt.z = (float)(axis.Z * Math.Sin(hrad));

                        vmd.MotionRecords.Add(newmotion);

                        if (da < 3)
                        {
                            nextangle = angle + 30;
                        }
                        else
                        {
                            nextangle = angle + 60;
                        }
                    }
                }


                // 出力 /////////////////////////////////////////////////////////////

                SaveFileDialog fd = new SaveFileDialog();

                //fd.InitialDirectory = Path.GetDirectoryName(host.OutFileName);
                fd.FileName = "Rotation1.vmd";
                fd.Filter = "VocaloidMotionData File|*.vmd";

                if (fd.ShowDialog() == DialogResult.OK)
                {
                    vmd.Write(fd.FileName);
                }

            }
            catch
            {
                MessageBox.Show("Error!", this.Text, MessageBoxButtons.OK, MessageBoxIcon.Exclamation);
            }

        }

        


    }
}