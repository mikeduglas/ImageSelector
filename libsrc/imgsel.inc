!* Image selector
!* mikeduglas@yandex.ru
!* 2022

  INCLUDE('winapi.inc'), ONCE
  INCLUDE('gdiplus.inc'), ONCE


typImgSelFramesData           QUEUE, TYPE
Descr                           STRING(256)
ImageData                       ANY
                              END


!!!<summary>Abstract class.</summary>
TBaseImageSelector            CLASS(TWnd), TYPE, MODULE('imgsel.clw'), LINK('imgsel.clw')
frameSize                       LIKE(SIZE), PROTECTED !- size of each frame
framesData                      &typImgSelFramesData, PROTECTED
framesImage                     &TGdiPlusBitmap, PROTECTED
frameOutline                    LIKE(SIZE), PROTECTED
scrollPos                       SIGNED, PROTECTED
currentFrame                    UNSIGNED, PROTECTED
bkColor                         LONG, PROTECTED
selColor                        LONG, PROTECTED
selPenWidth                     UNSIGNED, PROTECTED

Construct                       PROCEDURE()
Destruct                        PROCEDURE(), DERIVED
Init                            PROCEDURE(SIGNED pFeq), DERIVED
Kill                            PROCEDURE()
AddFile                         PROCEDURE(STRING pFileName, <STRING pDescr>)
!AddBlob                         PROCEDURE(BLOB pBlob, <STRING pDescr>)
AddRawData                      PROCEDURE(CONST *STRING pRawData, <STRING pDescr>)
SelectFrame                     PROCEDURE(UNSIGNED pFrameIndex), VIRTUAL
SetBackColor                    PROCEDURE(LONG pBackColor)
SetSelColor                     PROCEDURE(LONG pSelColor)
SetSelPenWidth                  PROCEDURE(UNSIGNED pPenWidth)
SetOutlineSize                  PROCEDURE(UNSIGNED pWidth, UNSIGNED pHeight)

PrepareControl                  PROCEDURE(), PROTECTED, VIRTUAL
CreateFramesImage               PROCEDURE(), PROTECTED, VIRTUAL
RedrawFramesImage               PROCEDURE(TDC pDc), PROTECTED, VIRTUAL
OnPaint                         PROCEDURE(), PROTECTED, VIRTUAL
OnVScroll                       PROCEDURE(UNSIGNED wParam, LONG lParam), BOOL, PROTECTED, VIRTUAL
OnHScroll                       PROCEDURE(UNSIGNED wParam, LONG lParam), BOOL, PROTECTED, VIRTUAL
OnMouseWheel                    PROCEDURE(UNSIGNED wParam), BOOL, PROTECTED, VIRTUAL
OnLButtonDown                   PROCEDURE(UNSIGNED wParam, LONG lParam), BOOL, PROTECTED, VIRTUAL
OnFrameSelected                 PROCEDURE(UNSIGNED pFrameIndex), PROTECTED, VIRTUAL
                              END


!!!<summary>Vertical selector.</summary>
TVerticalImageSelector        CLASS(TBaseImageSelector), TYPE, MODULE('imgsel.clw'), LINK('imgsel.clw')
SelectFrame                     PROCEDURE(UNSIGNED pFrameIndex), DERIVED
PrepareControl                  PROCEDURE(), PROTECTED, DERIVED
CreateFramesImage               PROCEDURE(), PROTECTED, DERIVED
RedrawFramesImage               PROCEDURE(TDC pDc), PROTECTED, DERIVED
OnVScroll                       PROCEDURE(UNSIGNED wParam, LONG lParam), BOOL, PROTECTED, DERIVED
OnMouseWheel                    PROCEDURE(UNSIGNED wParam), BOOL, PROTECTED, DERIVED
OnLButtonDown                   PROCEDURE(UNSIGNED wParam, LONG lParam), BOOL, PROTECTED, DERIVED
                              END


!!!<summary>Horizontal selector.</summary>
THorizontalImageSelector      CLASS(TBaseImageSelector), TYPE, MODULE('imgsel.clw'), LINK('imgsel.clw')
SelectFrame                     PROCEDURE(UNSIGNED pFrameIndex), DERIVED
PrepareControl                  PROCEDURE(), PROTECTED, DERIVED
CreateFramesImage               PROCEDURE(), PROTECTED, DERIVED
RedrawFramesImage               PROCEDURE(TDC pDc), PROTECTED, DERIVED
OnHScroll                       PROCEDURE(UNSIGNED wParam, LONG lParam), BOOL, PROTECTED, DERIVED
OnMouseWheel                    PROCEDURE(UNSIGNED wParam), BOOL, PROTECTED, DERIVED
OnLButtonDown                   PROCEDURE(UNSIGNED wParam, LONG lParam), BOOL, PROTECTED, DERIVED
                              END
