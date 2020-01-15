using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using PEPlugin;
using PEPlugin.Pmd;
using System.Windows.Forms;

namespace pmdDummyMorph
{
    public class pmdDummyMorph : IPEPlugin
    {

        IPEBuilder builder;


        public void Run(IPERunArgs args)
        {
            builder = args.Host.Builder;

            try
            {

                // PMD取得
                IPEXPmd pex = args.Host.Connector.Pmd.GetCurrentStateEx();

                if (pex.Vertex.Count <= 0)
                {
                    MessageBox.Show("頂点が見つかりません。", "pmdDummyMorph", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    return;
                }

                IPEXExpression exp1 = builder.CreateXExpression();
                IPEXExpressionOffset ofs1 = builder.CreateXExpressionOffset();
                exp1.Name = "ダミー";
                exp1.Category = ExpressionCategory.Others;
                exp1.Offsets.Add(ofs1);
                ofs1.Vertex = pex.Vertex[0];

                pex.Expression.Add(exp1);
                pex.FrameExpression.Add(exp1);

                // 編集したモデル情報でPMDエディタ側を更新
                args.Host.Connector.Pmd.UpdateEx(pex);

                // エディタ側の表示を更新する場合(一部を除いて表示更新の必要があります)
                args.Host.Connector.Form.UpdateList(PEPlugin.Pmd.UpdateObject.All);

            }
            catch
            {
                // 例外キャッチ:適宜設定してください


            }
        }



        public string Name
        {
            get { return "pmdDummyMorph"; }
        }

        public string Description
        {
            get { return "MME用などのダミーの表情を追加します"; }
        }

        public string Version
        {
            get
            {
                //自分自身のAssemblyを取得し、バージョンを返す
                System.Reflection.Assembly asm =
                    System.Reflection.Assembly.GetExecutingAssembly();
                System.Version ver = asm.GetName().Version;
                return ver.ToString();
            }
        }

        class option : IPEPluginOption
        {
            public bool Bootup { get { return false; } }  // 起動時実行
            public bool RegisterMenu { get { return true; } }  // プラグインメニューへの登録
            public string RegisterMenuText { get { return "ダミーモーフ付加"; } }
        }

        public IPEPluginOption Option
        {
            get { return new option(); }
        }

        public void Dispose()
        {
            ;
        }


    }
}
