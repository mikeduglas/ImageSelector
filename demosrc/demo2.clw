  PROGRAM

  INCLUDE('imgsel.inc'), ONCE

  MAP
    INCLUDE('printf.inc'), ONCE
  END

Window                        WINDOW('Horizontal image selector'),AT(,,356,205),CENTER,GRAY,SYSTEM, |
                                FONT('Segoe UI',9),RESIZE
                                IMAGE,AT(2,2,233,117),USE(?ImgViewer)
                                PROMPT('Set in code'),AT(2,122),USE(?LblDescr)
                                IMAGE,AT(2,143,,54),FULL,USE(?ImgSelector)
                              END


ThisImgSel                    CLASS(THorizontalImageSelector)
OnFrameSelected                 PROCEDURE(UNSIGNED pFrameIndex), PROTECTED, DERIVED
                              END


QDir                          QUEUE(File:Queue),PRE(QDir)
                              END
i                             LONG, AUTO

  CODE
  !- Open window
  OPEN(Window)
  ?LblDescr{PROP:Text} = ''

  !- Initialize image selector
  ThisImgSel.Init(?ImgSelector)
  
  !- Add all image files from \images folder to the selector
  DIRECTORY(QDir, '.\images\*.*', ff_:NORMAL)
  LOOP i=1 TO RECORDS(QDir)
    GET(QDir, i)
    ThisImgSel.AddFile('.\images\'& QDir.Name, QDir.Name)
  END
  
  ACCEPT
  END

  !- Clean up
  ThisImgSel.Kill()
  
  
!- Display selected image
ThisImgSel.OnFrameSelected    PROCEDURE(UNSIGNED pFrameIndex)
  CODE
  !- Get image file name from the queue
  GET(QDir, pFrameIndex)
  IF NOT ERRORCODE()
    ?ImgViewer{PROP:Text} = '.\images\'& QDir.Name
    ?LblDescr{PROP:Text} = printf('%s (%s bytes)', QDir.Name, LEFT(FORMAT(QDir.Size, @n12_)))
  END
  