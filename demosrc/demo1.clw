  PROGRAM

  INCLUDE('imgsel.inc'), ONCE

  MAP
    INCLUDE('printf.inc'), ONCE
  END

Window                        WINDOW('Vertical image selector'),AT(,,286,205),CENTER,GRAY,SYSTEM,FONT('Segoe UI',9), |
                                RESIZE
                                IMAGE,AT(2,2,180,125),USE(?ImgViewer)
                                PROMPT('Set in code'),AT(2,130),USE(?LblDescr)
                                IMAGE,AT(192,2,93),FULL,USE(?ImgSelector)
                              END


ThisImgSel                    CLASS(TVerticalImageSelector)
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
  