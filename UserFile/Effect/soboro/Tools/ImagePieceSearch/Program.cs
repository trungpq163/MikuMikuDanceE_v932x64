using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.IO;
using System.Drawing;

namespace ImagePieceSearch
{
    class Program
    {
        static void Main(string[] args)
        {

            if (args.Length < 2)
            {
                Console.WriteLine("Bad args");
                return;
            }

            if (!File.Exists(args[0]) || !File.Exists(args[1]))
            {
                Console.WriteLine("File not found");
                return;
            }

            Bitmap img1 = new Bitmap(args[0]);
            Bitmap img2 = new Bitmap(args[1]);

            int[, ,] img_ary1 = new int[img1.Width, img1.Height, 3];
            int[, ,] img_ary2 = new int[img2.Width, img2.Height, 3];

            
            int h1 = img1.Height - img2.Height;
            int w1 = img1.Width - img2.Width;
            int h2 = img2.Height;
            int w2 = img2.Width;

            int x, y, i, j, k;
            double r, rmax = 0;
            int rx = 0, ry = 0;

            double[,] r_ary = new double[w1, h1];
            
            //画像を配列に転送
            for (y = 0; y < img1.Height; y++)
            {
                for (x = 0; x < img1.Width; x++)
                {
                    Color c = img1.GetPixel(x, y);
                    img_ary1[x, y, 0] = c.R;
                    img_ary1[x, y, 1] = c.G;
                    img_ary1[x, y, 2] = c.B;
                }
            }

            //画像を配列に転送
            for (j = 0; j < h2; j++)
            {
                for (i = 0; i < w2; i++)
                {
                    Color c = img2.GetPixel(i, j);
                    img_ary2[i, j, 0] = c.R;
                    img_ary2[i, j, 1] = c.G;
                    img_ary2[i, j, 2] = c.B;
                }
            }

            //スキャン
            for (y = 0; y < h1; y++)
            {
                for (x = 0; x < w1; x++)
                {
                    r = 0;

                    for (k = 0; k < 3; k++) //色ループ
                    {
                        int f, g, fgsum = 0, f2sum = 0, g2sum = 0;

                        for (j = 0; j < h2; j++)
                        {
                            for (i = 0; i < w2; i++)
                            {
                                f = img_ary1[x + i, y + j, k];
                                g = img_ary2[i, j, k];

                                //積分
                                fgsum += f * g;
                                f2sum += f * f;
                                g2sum += g * g;
                            }
                        }

                        //相関係数の算出
                        if (f2sum != 0 && g2sum != 0)
                        {
                            r += (double)fgsum / Math.Sqrt((double)f2sum * (double)g2sum);
                        }
                    }

                    r /= 3.0; //色ごとの平均

                    //相関係数の保存
                    r_ary[x, y] = r;

                    //相関係数の比較
                    if (r > rmax)
                    {
                        rmax = r;
                        rx = x; ry = y;
                    }

                }
            }


            //サブピクセル解析

            double sx = rx, sy = ry;
            double p, q, rlast, rnext;

            if (0 < rx && rx < (w1 - 1))
            {
                rlast = r_ary[rx - 1, ry];
                rnext = r_ary[rx + 1, ry];
                p = rnext - rlast;
                q = rnext - 2 * rmax + rlast;
                if (Math.Abs(q) > 0.00001) sx = (double)rx - 0.5 * p / q;
            }
            if (0 < ry && ry < (h1 - 1))
            {
                rlast = r_ary[rx, ry - 1];
                rnext = r_ary[rx, ry + 1];
                p = rnext - rlast;
                q = rnext - 2 * rmax + rlast;
                if (Math.Abs(q) > 0.00001) sy = (double)ry - 0.5 * p / q;
            }

            //結果表示
            Console.WriteLine("左上位置: " + sx.ToString() + ", " + sy.ToString());
            sx += w2 * 0.5;
            sy += h2 * 0.5;
            Console.WriteLine("中心位置: " + sx.ToString() + ", " + sy.ToString());
            Console.WriteLine("相関係数: " + rmax.ToString());

        }
    }
}
