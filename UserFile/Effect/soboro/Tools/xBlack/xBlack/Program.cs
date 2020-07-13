using System;
using System.Collections.Generic;
using System.Text;
using System.IO;

namespace xBlack
{
    class Program
    {
        static void Main(string[] args)
        {
            foreach (string arg in args)
            {
                if (arg.ToLower().EndsWith(".x"))
                {
                    try
                    {
                        Console.WriteLine("Convert: " + arg);

                        Encoding Shift_JIS = Encoding.GetEncoding(932);

                        FileStream fs = new FileStream(arg, FileMode.Open, FileAccess.Read);
                        StreamReader sr = new StreamReader(fs, Shift_JIS);

                        string x = sr.ReadToEnd();

                        sr.Close();


                        x = xConvert(x);


                        string outfile = Path.Combine(Path.GetDirectoryName(arg), Path.GetFileNameWithoutExtension(arg) + "_black.x");
                        FileStream fso = new FileStream(outfile, FileMode.Create, FileAccess.Write);
                        StreamWriter sw = new StreamWriter(fso, Shift_JIS);
                        sw.Write(x);

                        sw.Close();

                    }
                    catch
                    {
                        Console.Error.WriteLine("Error!");
                    }
                }
            }
        }

        const string MaterialScript = "Material";

        const string MaterialBlack = "{\r"
            + "  0.0000;0.0000;0.0000;1.0;;\r"
            + "  5.0000;\r"
            + "  0.0000;0.0000;0.0000;;\r"
            + "  0.0000;0.0000;0.0000;;\r"
            + "}";

        static string xConvert(string x)
        {
            int i = 0, j;

            //改行コードを変換
            x = x.Replace("\r\n", "\r");
            x = x.Replace("\n", "\r");

            while (true)
            {
                //"Material"を検索
                int index = x.IndexOf(MaterialScript, i);
                
                if (index < 0)
                {
                    break; //見つからなければ終了
                }
                else
                {
                    bool isMaterial = true;
                    int indent = 0;

                    //行頭までにスペース以外があったらマテリアル指定でない
                    for (j = index - 1; j >= 0; j--)
                    {
                        char c = x[j];
                        if (c == '\r')
                        {
                            break;
                        }
                        else if (c == ' ')
                        {
                            indent++;
                        }
                        else
                        {
                            isMaterial = false;
                        }
                    }

                    //次の文字が" "または"{"でなければマテリアル指定でない
                    char nextchar = x[index + MaterialScript.Length];
                    if (nextchar != ' ' && nextchar != '{')
                    {
                        isMaterial = false;
                    }

                    //マテリアル指定と判断できる時
                    if (isMaterial)
                    {
                        int start = 0, length = 0;
                        int nestcount = 0;

                        //マテリアルパラメータの指定範囲を探す
                        for (j = index + MaterialScript.Length; j < x.Length; j++)
                        {
                            if (x[j] == '{')
                            {
                                nestcount++;
                                if (start == 0) start = j; //最初の"{"
                            }
                            else if (x[j] == '}')
                            {
                                nestcount--;
                                if (start != 0 && nestcount == 0) break; //"{ }"が閉じた
                            }
                        }

                        length = j - start + 1;

                        //明らかに長すぎておかしい時はスキップ
                        if (length > 500)
                        {
                            i = index + MaterialScript.Length;
                        }
                        else
                        {

                            //マテリアルを黒に置換＋インデント合わせ
                            x = x.Remove(start, length);
                            x = x.Insert(start, MaterialBlack.Replace("\r", "\r".PadRight(indent + 1)));

                            i = start + MaterialBlack.Length;

                        }

                    }
                    else
                    {
                        i = index + MaterialScript.Length;
                    }
                }
            }

            //改行コードをWindows仕様に戻す
            x = x.Replace("\r", Environment.NewLine);

            return x;
        }
    }

    
}
