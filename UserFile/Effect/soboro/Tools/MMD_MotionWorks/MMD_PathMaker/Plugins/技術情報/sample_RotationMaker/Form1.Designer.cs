namespace RotationMaker
{
    partial class Form1
    {
        /// <summary>
        /// 必要なデザイナ変数です。
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        /// 使用中のリソースをすべてクリーンアップします。
        /// </summary>
        /// <param name="disposing">マネージ リソースが破棄される場合 true、破棄されない場合は false です。</param>
        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
            {
                components.Dispose();
            }
            base.Dispose(disposing);
        }

        #region Windows フォーム デザイナで生成されたコード

        /// <summary>
        /// デザイナ サポートに必要なメソッドです。このメソッドの内容を
        /// コード エディタで変更しないでください。
        /// </summary>
        private void InitializeComponent()
        {
            this.button1 = new System.Windows.Forms.Button();
            this.label1 = new System.Windows.Forms.Label();
            this.txtBone = new System.Windows.Forms.TextBox();
            this.txtVal = new System.Windows.Forms.TextBox();
            this.label2 = new System.Windows.Forms.Label();
            this.label3 = new System.Windows.Forms.Label();
            this.label4 = new System.Windows.Forms.Label();
            this.txtX = new System.Windows.Forms.TextBox();
            this.txtY = new System.Windows.Forms.TextBox();
            this.label5 = new System.Windows.Forms.Label();
            this.txtZ = new System.Windows.Forms.TextBox();
            this.label6 = new System.Windows.Forms.Label();
            this.SuspendLayout();
            // 
            // button1
            // 
            this.button1.Location = new System.Drawing.Point(160, 106);
            this.button1.Name = "button1";
            this.button1.Size = new System.Drawing.Size(97, 27);
            this.button1.TabIndex = 0;
            this.button1.Text = "出力...";
            this.button1.UseVisualStyleBackColor = true;
            this.button1.Click += new System.EventHandler(this.button1_Click);
            // 
            // label1
            // 
            this.label1.AutoSize = true;
            this.label1.Location = new System.Drawing.Point(127, 9);
            this.label1.Name = "label1";
            this.label1.Size = new System.Drawing.Size(48, 12);
            this.label1.TabIndex = 1;
            this.label1.Text = "ボーン名:";
            // 
            // txtBone
            // 
            this.txtBone.Location = new System.Drawing.Point(139, 24);
            this.txtBone.Name = "txtBone";
            this.txtBone.Size = new System.Drawing.Size(86, 19);
            this.txtBone.TabIndex = 2;
            this.txtBone.Text = "センター";
            // 
            // txtVal
            // 
            this.txtVal.Location = new System.Drawing.Point(139, 74);
            this.txtVal.Name = "txtVal";
            this.txtVal.Size = new System.Drawing.Size(86, 19);
            this.txtVal.TabIndex = 4;
            this.txtVal.Text = "10";
            // 
            // label2
            // 
            this.label2.AutoSize = true;
            this.label2.Location = new System.Drawing.Point(127, 59);
            this.label2.Name = "label2";
            this.label2.Size = new System.Drawing.Size(131, 12);
            this.label2.TabIndex = 3;
            this.label2.Text = "回転係数[度/MMD距離]:";
            // 
            // label3
            // 
            this.label3.AutoSize = true;
            this.label3.Location = new System.Drawing.Point(12, 9);
            this.label3.Name = "label3";
            this.label3.Size = new System.Drawing.Size(79, 12);
            this.label3.TabIndex = 5;
            this.label3.Text = "回転軸ベクトル:";
            // 
            // label4
            // 
            this.label4.AutoSize = true;
            this.label4.Location = new System.Drawing.Point(25, 27);
            this.label4.Name = "label4";
            this.label4.Size = new System.Drawing.Size(14, 12);
            this.label4.TabIndex = 6;
            this.label4.Text = "X:";
            // 
            // txtX
            // 
            this.txtX.Location = new System.Drawing.Point(45, 24);
            this.txtX.Name = "txtX";
            this.txtX.Size = new System.Drawing.Size(56, 19);
            this.txtX.TabIndex = 7;
            this.txtX.Text = "0";
            // 
            // txtY
            // 
            this.txtY.Location = new System.Drawing.Point(45, 49);
            this.txtY.Name = "txtY";
            this.txtY.Size = new System.Drawing.Size(56, 19);
            this.txtY.TabIndex = 9;
            this.txtY.Text = "1";
            // 
            // label5
            // 
            this.label5.AutoSize = true;
            this.label5.Location = new System.Drawing.Point(25, 52);
            this.label5.Name = "label5";
            this.label5.Size = new System.Drawing.Size(14, 12);
            this.label5.TabIndex = 8;
            this.label5.Text = "Y:";
            // 
            // txtZ
            // 
            this.txtZ.Location = new System.Drawing.Point(45, 74);
            this.txtZ.Name = "txtZ";
            this.txtZ.Size = new System.Drawing.Size(56, 19);
            this.txtZ.TabIndex = 11;
            this.txtZ.Text = "0";
            // 
            // label6
            // 
            this.label6.AutoSize = true;
            this.label6.Location = new System.Drawing.Point(25, 77);
            this.label6.Name = "label6";
            this.label6.Size = new System.Drawing.Size(14, 12);
            this.label6.TabIndex = 10;
            this.label6.Text = "Z:";
            // 
            // Form1
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(6F, 12F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(272, 145);
            this.Controls.Add(this.txtZ);
            this.Controls.Add(this.label6);
            this.Controls.Add(this.txtY);
            this.Controls.Add(this.label5);
            this.Controls.Add(this.txtX);
            this.Controls.Add(this.label4);
            this.Controls.Add(this.label3);
            this.Controls.Add(this.txtVal);
            this.Controls.Add(this.label2);
            this.Controls.Add(this.txtBone);
            this.Controls.Add(this.label1);
            this.Controls.Add(this.button1);
            this.FormBorderStyle = System.Windows.Forms.FormBorderStyle.FixedSingle;
            this.MaximizeBox = false;
            this.MinimizeBox = false;
            this.Name = "Form1";
            this.Text = "回転メイカー";
            this.Load += new System.EventHandler(this.Form1_Load);
            this.ResumeLayout(false);
            this.PerformLayout();

        }

        #endregion

        private System.Windows.Forms.Button button1;
        private System.Windows.Forms.Label label1;
        private System.Windows.Forms.TextBox txtBone;
        private System.Windows.Forms.TextBox txtVal;
        private System.Windows.Forms.Label label2;
        private System.Windows.Forms.Label label3;
        private System.Windows.Forms.Label label4;
        private System.Windows.Forms.TextBox txtX;
        private System.Windows.Forms.TextBox txtY;
        private System.Windows.Forms.Label label5;
        private System.Windows.Forms.TextBox txtZ;
        private System.Windows.Forms.Label label6;
    }
}