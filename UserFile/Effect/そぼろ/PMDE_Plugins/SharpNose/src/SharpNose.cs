using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

using System.Windows.Forms;

using PEPlugin;
using PEPlugin.Pmx;

namespace SharpNose
{
    public class SharpNose : IPEPlugin
    {


        public void Run(IPERunArgs args)
        {

            
            int [] vtxids = args.Host.Connector.View.PMDView.GetSelectedVertexIndices();
            
            if (vtxids.Length != 1)
            {
                MessageBox.Show("頂点選択数が1でしか実行できません", this.Name, MessageBoxButtons.OK, MessageBoxIcon.Exclamation);
                return;
            }

            IPXPmx pmx = args.Host.Connector.Pmx.GetCurrentState();

            IPXVertex vtx = pmx.Vertex[vtxids[0]];

            List<IPXFace> faces = new List<IPXFace>();

            int i = 0;
            
            foreach (IPXMaterial mat in pmx.Material)
            {
                foreach (IPXFace face in mat.Faces)
                {
                    IPXVertex vtx2 = null;

                    if (face.Vertex1.Equals(vtx))
                    {
                        vtx2 = (i == 0) ? vtx : (IPXVertex)vtx.Clone();
                        PEPlugin.SDX.V3 vec1 = face.Vertex2.Position - face.Vertex1.Position;
                        PEPlugin.SDX.V3 vec2 = face.Vertex3.Position - face.Vertex1.Position;
                        vtx2.Normal = normalize(cross(vec1, vec2));
                        face.Vertex1 = vtx2;
                    }
                    else if (face.Vertex2.Equals(vtx))
                    {
                        vtx2 = (i == 0) ? vtx : (IPXVertex)vtx.Clone();
                        PEPlugin.SDX.V3 vec1 = face.Vertex3.Position - face.Vertex2.Position;
                        PEPlugin.SDX.V3 vec2 = face.Vertex1.Position - face.Vertex2.Position;
                        vtx2.Normal = normalize(cross(vec1, vec2));
                        face.Vertex2 = vtx2;
                    }
                    else if (face.Vertex3.Equals(vtx))
                    {
                        vtx2 = (i == 0) ? vtx : (IPXVertex)vtx.Clone();
                        PEPlugin.SDX.V3 vec1 = face.Vertex1.Position - face.Vertex3.Position;
                        PEPlugin.SDX.V3 vec2 = face.Vertex2.Position - face.Vertex3.Position;
                        vtx2.Normal = normalize(cross(vec1, vec2));
                        face.Vertex3 = vtx2;
                    }

                    if (vtx2 != null)
                    {
                        if (i != 0)
                        {
                            pmx.Vertex.Add(vtx2);
                        }
                        i++;
                    }
                }
            }



            args.Host.Connector.Pmx.Update(pmx);
            args.Host.Connector.Form.UpdateList(PEPlugin.Pmd.UpdateObject.All);
            args.Host.Connector.View.PMDView.UpdateModel();
            args.Host.Connector.View.PMDView.UpdateView();



        }

        /// <summary> ベクトルのクロス積を返します </summary>
        public static PEPlugin.SDX.V3 cross(PEPlugin.SDX.V3 a, PEPlugin.SDX.V3 b)
        {
            float x = a.Y * b.Z - a.Z * b.Y;
            float y = a.Z * b.X - a.X * b.Z;
            float z = a.X * b.Y - a.Y * b.X;

            return new PEPlugin.SDX.V3(x, y, z);
        }

        /// <summary> ベクトルの長さを返します </summary>
        public static float length(PEPlugin.SDX.V3 vec)
        {
            return (float)Math.Sqrt(vec.X * vec.X + vec.Y * vec.Y + vec.Z * vec.Z);
        }

        /// <summary> ベクトルを正規化して返します </summary>
        public static PEPlugin.SDX.V3 normalize(PEPlugin.SDX.V3 vec)
        {
            float len = length(vec);
            if (len == 0.0f) return vec;

            return (vec / len);
        }




        public string Name
        {
            get { return "SharpNose"; }
        }

        public string Description
        {
            get { return ""; }
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
            public string RegisterMenuText { get { return "とがり鼻"; } }
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
