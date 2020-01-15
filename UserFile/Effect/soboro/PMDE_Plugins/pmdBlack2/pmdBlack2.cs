using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using PEPlugin;

namespace pmdBlack2
{
    public class pmdBlack : IPEPlugin
    {
        public void Run(IPERunArgs args)
        {
            try
            {
                // 現在のPMDデータを複製取得
                PEPlugin.Pmd.IPEPmd pe = args.Host.Connector.Pmd.GetCurrentState();

                // モデル名変更
                //pe.Header.ModelName = pe.Header.ModelName + "(黒)";

                for (int i = 0; i < pe.Material.Count; i++)
                {
                    pe.Material[i].Diffuse.R = 0;
                    pe.Material[i].Diffuse.G = 0;
                    pe.Material[i].Diffuse.B = 0;
                    pe.Material[i].Diffuse.A = 1;
                    pe.Material[i].Specular.R = 0;
                    pe.Material[i].Specular.G = 0;
                    pe.Material[i].Specular.B = 0;
                    pe.Material[i].Ambient.R = 0;
                    pe.Material[i].Ambient.G = 0;
                    pe.Material[i].Ambient.B = 0;

                    pe.Material[i].TextureFileName = "";
                    pe.Material[i].SphereFileName = "";

                }

                // 編集したモデル情報でPMDエディタ側を更新
                args.Host.Connector.Pmd.Update(pe);

                // エディタ側の表示を更新する場合(一部を除いて表示更新の必要があります)
                args.Host.Connector.Form.UpdateList(PEPlugin.Pmd.UpdateObject.Material);

                args.Host.Connector.View.PMDView.UpdateModel();
                args.Host.Connector.View.PMDView.UpdateView();
            }
            catch
            {
                // 例外キャッチ:適宜設定してください
            }
        }

        public string Name
        {
            get { return "pmdBlack"; }
        }

        public string Description
        {
            get { return "素材をすべて黒に変えます"; }
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
            public string RegisterMenuText { get { return ""; } }
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
