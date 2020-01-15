using System;
using System.Collections.Generic;
using System.Text;
using System.Runtime;
using System.Diagnostics;
using System.Runtime.InteropServices;


namespace PathMakerPlugin
{
    /// <summary>
    /// MMD本体へのアクセスを提供します
    /// </summary>
    public class MMDAccess
    {

        delegate int WNDENUMPROC(IntPtr hwnd, int lParam);

        [DllImport("user32.dll")]
        private static extern int EnumChildWindows(IntPtr hWndParent, WNDENUMPROC lpEnumFunc, int lParam);

        [DllImport("User32.dll", EntryPoint = "SendMessage")]
        private static extern Int32 SendMessage(IntPtr hWnd, Int32 Msg, Int32 wParam, Int32 lParam);

        [DllImport("User32.dll", EntryPoint = "SendMessage")]
        private static extern Int32 SendMessage(IntPtr hWnd, Int32 Msg, Int32 wParam, StringBuilder s);

        [DllImport("User32.Dll", CharSet = CharSet.Unicode)]
        private static extern int GetClassName(IntPtr hWnd, StringBuilder s, int nMaxCount);

        [DllImport("User32.Dll")]
        private static extern bool IsWindow(IntPtr hWnd);


        const Int32 CB_GETCOUNT = 0x0146;
        const Int32 CB_GETCURSEL = 0x0147;
        const Int32 CB_GETLBTEXT = 0x0148;
        const Int32 CB_SETCURSEL = 0x014E;

        /// <summary>
        /// MMDのプロセスを探します
        /// </summary>
        /// <returns>MMDのプロセス</returns>
        public Process SearchMainWindow()
        {
            foreach (Process p in Process.GetProcesses())
            {
                if (p.MainWindowHandle != IntPtr.Zero)
                {
                    //Debug.WriteLine(p.ProcessName  + " : " + p.MainWindowTitle);
                    
                    const string mmdstr = "MikuMikuDance";
                    if (p.ProcessName.StartsWith(mmdstr) && p.MainWindowTitle.StartsWith(mmdstr))
                    {
                        return p;
                    }
                }
            }

            return null;
        }

        /// <summary>
        /// MMDのモデル選択コンボボックスが見つかっている時、選択されているモデルの名前を返します
        /// </summary>
        public string ActorName
        {
            get
            {
                IntPtr hWnd = ModelListComboBoxHandle;
                if (hWnd == IntPtr.Zero) return "";
                int selectindex = SendMessage(hWnd, CB_GETCURSEL, 0, 0);

                if (selectindex >= 0)
                {
                    StringBuilder sb = new StringBuilder(256);
                    SendMessage(hWnd, CB_GETLBTEXT, selectindex, sb);
                    string selecteditem = sb.ToString();

                    return selecteditem;
                }

                return "";
            }
        }

        /// <summary>
        /// MMDのモデル選択コンボボックスが見つかっている時、カメラが選択されているか返します
        /// </summary>
        public bool IsCamera
        {
            get
            {
                IntPtr hWnd = ModelListComboBoxHandle;
                if (hWnd == IntPtr.Zero) return false;
                int selectindex = SendMessage(hWnd, CB_GETCURSEL, 0, 0);

                return (selectindex == 0);
            }
        }

        /// <summary>
        /// MMDのモデル選択コンボボックスが見つかっている時、モデル選択コンボボックスのハンドルを返します
        /// </summary>
        public IntPtr ModelListComboBoxHandle
        {
            get
            {
                if (mlcb_hwnd != IntPtr.Zero)
                {
                    if (IsWindow(mlcb_hwnd))
                    {
                        return mlcb_hwnd;
                    }
                }
                return IntPtr.Zero;
            }
        }

        IntPtr mlcb_hwnd = IntPtr.Zero;

        /// <summary>
        /// MMDのモデル選択コンボボックスが見つかっていない時、モデル選択コンボボックスを探します
        /// </summary>
        /// <returns>見つかったらtrue、見つからなければfalseを返します</returns>
        public bool SearchModelListComboBox()
        {
            if (ModelListComboBoxHandle != IntPtr.Zero) return true;

            Process p = SearchMainWindow();

            if (p == null) return false;

            
            IntPtr hwnd = p.MainWindowHandle;

            EnumChildWindows(hwnd, EnumWindowsProc, 0);

            //Debug.WriteLine(actname);

            mlcb_hwnd = _mlcb_hwnd;

            return (mlcb_hwnd != IntPtr.Zero);
        }

        static IntPtr _mlcb_hwnd = IntPtr.Zero;

        static int EnumWindowsProc(IntPtr hWnd, int lParam) {
            StringBuilder sb = new StringBuilder(256);

            GetClassName(hWnd, sb, 256);

            string clsname = sb.ToString();

            int listcount;
            string listfirst;
            
            if (clsname.CompareTo("ComboBox") == 0)
            {
                listcount = SendMessage(hWnd, CB_GETCOUNT, 0, 0);

                if (listcount > 0)
                {
                    
                    SendMessage(hWnd, CB_GETLBTEXT, 0, sb);
                    
                    listfirst = sb.ToString();
                    if (listfirst.CompareTo("ｶﾒﾗ･照明･ｱｸｾｻﾘ") == 0)
                    {

                        _mlcb_hwnd = hWnd;

                        
                    }
                }
            }
            
            return 1; 
        }

    }
}
