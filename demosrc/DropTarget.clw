  PROGRAM

  INCLUDE('winapi.inc'), ONCE

  MAP
    wndProc(HWND hWnd, ULONG wMsg, UNSIGNED wParam, LONG lParam), LONG, PASCAL, PRIVATE

    INCLUDE('printf.inc'), ONCE
  END

Window                        WINDOW('Drop target'),AT(,,214,131),GRAY,SYSTEM,FONT('Segoe UI',9)
                              END

TSimpleWindow                 CLASS(TCWnd), TYPE
OnCopyData                      PROCEDURE(UNSIGNED wParam, LONG lParam), BOOL, VIRTUAL
                              END

thisWin                       TSimpleWindow

WM_COPYDATA                   EQUATE(004Ah)

tagCOPYDATASTRUCT             GROUP, TYPE
dwData                          LONG
cbData                          ULONG
lpData                          LONG
                              END

  CODE
  OPEN(Window)

  !- Sets the window's messaging procedure (wndProc)
  thisWin.Init(Window)
  thisWin.SetWndProc(ADDRESS(wndProc), ADDRESS(thisWin))

  ACCEPT
  END
  
  
wndProc                       PROCEDURE(HWND hWnd,ULONG wMsg,UNSIGNED wParam,LONG lParam)
win                             TWnd
this                            &TSimpleWindow
  CODE
  win.SetHandle(hWnd)
  !- get TSimpleWindow instance
  this &= win.GetWindowLong(GWL_USERDATA)
  IF this &= NULL
    !- not our window
    RETURN win.DefWindowProc(wMsg, wParam, lParam)
  END
  
  CASE wMsg
  OF WM_COPYDATA
    RETURN this.OnCopyData(wParam, lParam)
  END
  
  !- call original window proc
  RETURN this.CallWindowProc(wMsg, wParam, lParam)

TSimpleWindow.OnCopyData      PROCEDURE(UNSIGNED wParam, LONG lParam)
cds                             &tagCOPYDATASTRUCT
imagePath                       &STRING
  CODE
  cds &= (lParam)
  CASE cds.dwData
  OF 0  !- Image dropped
    imagePath &= (cds.lpData) &':'& cds.cbData
    Window{PROP:WallPaper} = imagePath
    RETURN TRUE
  END
  
  RETURN FALSE
