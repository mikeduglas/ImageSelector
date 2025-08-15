15.08.2025
- New InsertFrame method that insert an image to existing image collection at the position specified by index parameter, unlike the AddFile methods 
that form the initial collection.
- demo1 was updated to demonstrate the InsertFrame usage.

31.03.2023
- Removed CONST from method parameter declaration.

22.09.2022
- Drag mode. If enabled, you can drag and drop selected frame.
- EnableDragging method enables or disables drag mode.
- OnDrop event fires when a user drops dragging frame.
- Demo1 project: added "Enable drag-n-drop" checkbox.
- DropTarget demo project: the window changes its background to the image dropped from the Demo1.
- winapi 22.09.2022 revision required.

31.08.2022
- New methods UpdateFrame, DeleteFrame.
- demo1.clw demonstrates a usage of new features.

29.08.2022
- New SetFrameBackColor property.
- New EnsureVisible method: ensures that the specified frame is visible within the control, scrolling the contents of the control if necessary.
- Fixed SelectFrame: it did not update frame selection.
- New NumberOfFrames method returns a number of frames in the control.
- New GetSelectedIndex property returns an index of selected frame.

An example of scrolling up and down:
```
R::ScrollDown                 ROUTINE
  DATA
frameIndex  UNSIGNED, AUTO
  CODE
  frameIndex = ThisImgSel.GetSelectedIndex()
  frameIndex += 1
  IF frameIndex > ThisImgSel.NumberOfFrames()
    frameIndex = 1
  END
  
  ThisImgSel.EnsureVisible(frameIndex)
  ThisImgSel.SelectFrame(frameIndex)
    
R::ScrollUp                   ROUTINE
  DATA
frameIndex  UNSIGNED, AUTO
  CODE
  frameIndex = ThisImgSel.GetSelectedIndex()
  frameIndex -= 1
  IF frameIndex = 0
    frameIndex = ThisImgSel.NumberOfFrames()
  END
  
  ThisImgSel.EnsureVisible(frameIndex)
  ThisImgSel.SelectFrame(frameIndex)
```



28.08.2022
- New options for thumbnails: 1) retain image aspect ratio, and 2) center thumbnail.
- Fixed a bug occuring when empty or not existing file was passed to AddFile().

27.08.2022
- Non image files are correctly processed now.
- Added a legal way to reload the control with another set of images.
- Fixed a crash when a set of images is empty.
- Fixed a visual artefacts when a set of images is small.