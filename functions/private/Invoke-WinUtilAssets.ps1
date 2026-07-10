function Invoke-WinUtilAssets {
  param (
      $type,
      $Size,
      [switch]$render
  )

  # Create the Viewbox and set its size
  $LogoViewbox = New-Object Windows.Controls.Viewbox
  $LogoViewbox.Width = $Size
  $LogoViewbox.Height = $Size

  # Create a Canvas to hold the paths
  $canvas = New-Object Windows.Controls.Canvas
  $canvas.Width = 100
  $canvas.Height = 100

  # Define a scale factor for the content inside the Canvas
  $scaleFactor = $Size / 100

  # Apply a scale transform to the Canvas content
  $scaleTransform = New-Object Windows.Media.ScaleTransform($scaleFactor, $scaleFactor)
  $canvas.LayoutTransform = $scaleTransform

  switch ($type) {
      'logo' {
          # Holha1337 终端徽记:霓虹终端窗 + >H_ 提示符 + 闪烁光标
          # 与 EXE 图标 >H_ 终端风格统一,暗黑霓虹 gamesense 质感

          # 终端"屏幕"圆角矩形(深色底 + 霓虹渐变描边 + 辉光呼吸)
          $screen = New-Object Windows.Shapes.Rectangle
          $screen.Width = 84; $screen.Height = 60
          $screen.RadiusX = 13; $screen.RadiusY = 13
          [Windows.Controls.Canvas]::SetLeft($screen, 8)
          [Windows.Controls.Canvas]::SetTop($screen, 20)
          $screen.Fill = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#0B1730")
          $scStroke = New-Object Windows.Media.LinearGradientBrush
          $scStroke.StartPoint = "0,0"; $scStroke.EndPoint = "1,1"
          $scStroke.GradientStops.Add((New-Object Windows.Media.GradientStop([Windows.Media.ColorConverter]::ConvertFromString("#38F9D7"), 0)))
          $scStroke.GradientStops.Add((New-Object Windows.Media.GradientStop([Windows.Media.ColorConverter]::ConvertFromString("#43A6FF"), 0.5)))
          $scStroke.GradientStops.Add((New-Object Windows.Media.GradientStop([Windows.Media.ColorConverter]::ConvertFromString("#C86BFF"), 1)))
          $screen.Stroke = $scStroke
          $screen.StrokeThickness = 4
          $scGlow = New-Object Windows.Media.Effects.DropShadowEffect
          $scGlow.Color = [Windows.Media.ColorConverter]::ConvertFromString("#38F9D7")
          $scGlow.BlurRadius = 16; $scGlow.ShadowDepth = 0; $scGlow.Opacity = 0.85
          $screen.Effect = $scGlow
          # 辉光呼吸脉冲(BlurRadius 9<->22 循环,营造霓虹脉动)
          $scPulse = New-Object Windows.Media.Animation.DoubleAnimation
          $scPulse.From = 9; $scPulse.To = 22
          $scPulse.Duration = New-Object Windows.Duration([TimeSpan]::FromSeconds(1.4))
          $scPulse.AutoReverse = $true
          $scPulse.RepeatBehavior = [Windows.Media.Animation.RepeatBehavior]::Forever
          $scGlow.BeginAnimation([Windows.Media.Effects.DropShadowEffect]::BlurRadiusProperty, $scPulse)

          # >H 提示符(霓虹渐变等宽粗体)
          $prompt = New-Object Windows.Controls.TextBlock
          $prompt.Text = ">H"; $prompt.FontFamily = "Consolas"; $prompt.FontSize = 34; $prompt.FontWeight = "Bold"
          $pGrad = New-Object Windows.Media.LinearGradientBrush
          $pGrad.StartPoint = "0,0"; $pGrad.EndPoint = "1,1"
          $pGrad.GradientStops.Add((New-Object Windows.Media.GradientStop([Windows.Media.ColorConverter]::ConvertFromString("#5CFFE6"), 0)))
          $pGrad.GradientStops.Add((New-Object Windows.Media.GradientStop([Windows.Media.ColorConverter]::ConvertFromString("#43A6FF"), 0.6)))
          $pGrad.GradientStops.Add((New-Object Windows.Media.GradientStop([Windows.Media.ColorConverter]::ConvertFromString("#C86BFF"), 1)))
          $prompt.Foreground = $pGrad
          [Windows.Controls.Canvas]::SetLeft($prompt, 21); [Windows.Controls.Canvas]::SetTop($prompt, 26)

          # _ 光标(青色,闪烁 opacity 动画,终端质感)
          $cursor = New-Object Windows.Controls.TextBlock
          $cursor.Text = "_"; $cursor.FontFamily = "Consolas"; $cursor.FontSize = 34; $cursor.FontWeight = "Bold"
          $cursor.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#5CFFE6")
          [Windows.Controls.Canvas]::SetLeft($cursor, 59); [Windows.Controls.Canvas]::SetTop($cursor, 26)
          $blink = New-Object Windows.Media.Animation.DoubleAnimation
          $blink.From = 1; $blink.To = 0
          $blink.Duration = New-Object Windows.Duration([TimeSpan]::FromSeconds(0.6))
          $blink.AutoReverse = $true
          $blink.RepeatBehavior = [Windows.Media.Animation.RepeatBehavior]::Forever
          $cursor.BeginAnimation([Windows.UIElement]::OpacityProperty, $blink)

          $canvas.Children.Add($screen) | Out-Null
          $canvas.Children.Add($prompt) | Out-Null
          $canvas.Children.Add($cursor) | Out-Null
      }
      'checkmark' {
          $canvas.Width = 512
          $canvas.Height = 512

          $scaleFactor = $Size / 2.54
          $scaleTransform = New-Object Windows.Media.ScaleTransform($scaleFactor, $scaleFactor)
          $canvas.LayoutTransform = $scaleTransform

          # Define the circle path
          $circlePathData = "M 1.27,0 A 1.27,1.27 0 1,0 1.27,2.54 A 1.27,1.27 0 1,0 1.27,0"
          $circlePath = New-Object Windows.Shapes.Path
          $circlePath.Data = [Windows.Media.Geometry]::Parse($circlePathData)
          $circlePath.Fill = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#39ba00")

          # Define the checkmark path
          $checkmarkPathData = "M 0.873 1.89 L 0.41 1.391 A 0.17 0.17 0 0 1 0.418 1.151 A 0.17 0.17 0 0 1 0.658 1.16 L 1.016 1.543 L 1.583 1.013 A 0.17 0.17 0 0 1 1.599 1 L 1.865 0.751 A 0.17 0.17 0 0 1 2.105 0.759 A 0.17 0.17 0 0 1 2.097 0.999 L 1.282 1.759 L 0.999 2.022 L 0.874 1.888 Z"
          $checkmarkPath = New-Object Windows.Shapes.Path
          $checkmarkPath.Data = [Windows.Media.Geometry]::Parse($checkmarkPathData)
          $checkmarkPath.Fill = [Windows.Media.Brushes]::White

          # Add the paths to the Canvas
          $canvas.Children.Add($circlePath) | Out-Null
          $canvas.Children.Add($checkmarkPath) | Out-Null
      }
      'warning' {
          $canvas.Width = 512
          $canvas.Height = 512

          # Define a scale factor for the content inside the Canvas
          $scaleFactor = $Size / 512  # Adjust scaling based on the canvas size
          $scaleTransform = New-Object Windows.Media.ScaleTransform($scaleFactor, $scaleFactor)
          $canvas.LayoutTransform = $scaleTransform

          # Define the circle path
          $circlePathData = "M 256,0 A 256,256 0 1,0 256,512 A 256,256 0 1,0 256,0"
          $circlePath = New-Object Windows.Shapes.Path
          $circlePath.Data = [Windows.Media.Geometry]::Parse($circlePathData)
          $circlePath.Fill = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#f41b43")

          # Define the exclamation mark path
          $exclamationPathData = "M 256 307.2 A 35.89 35.89 0 0 1 220.14 272.74 L 215.41 153.3 A 35.89 35.89 0 0 1 251.27 116 H 260.73 A 35.89 35.89 0 0 1 296.59 153.3 L 291.86 272.74 A 35.89 35.89 0 0 1 256 307.2 Z"
          $exclamationPath = New-Object Windows.Shapes.Path
          $exclamationPath.Data = [Windows.Media.Geometry]::Parse($exclamationPathData)
          $exclamationPath.Fill = [Windows.Media.Brushes]::White

          # Get the bounds of the exclamation mark path
          $exclamationBounds = $exclamationPath.Data.Bounds

          # Calculate the center position for the exclamation mark path
          $exclamationCenterX = ($canvas.Width - $exclamationBounds.Width) / 2 - $exclamationBounds.X
          $exclamationPath.SetValue([Windows.Controls.Canvas]::LeftProperty, $exclamationCenterX)

          # Define the rounded rectangle at the bottom (dot of exclamation mark)
          $roundedRectangle = New-Object Windows.Shapes.Rectangle
          $roundedRectangle.Width = 80
          $roundedRectangle.Height = 80
          $roundedRectangle.RadiusX = 30
          $roundedRectangle.RadiusY = 30
          $roundedRectangle.Fill = [Windows.Media.Brushes]::White

          # Calculate the center position for the rounded rectangle
          $centerX = ($canvas.Width - $roundedRectangle.Width) / 2
          $roundedRectangle.SetValue([Windows.Controls.Canvas]::LeftProperty, $centerX)
          $roundedRectangle.SetValue([Windows.Controls.Canvas]::TopProperty, 324.34)

          # Add the paths to the Canvas
          $canvas.Children.Add($circlePath) | Out-Null
          $canvas.Children.Add($exclamationPath) | Out-Null
          $canvas.Children.Add($roundedRectangle) | Out-Null
      }
      default {
          Write-Host "Invalid type: $type"
      }
  }

  # Add the Canvas to the Viewbox
  $LogoViewbox.Child = $canvas

  if ($render) {
      # Measure and arrange the canvas to ensure proper rendering
      $canvas.Measure([Windows.Size]::new($canvas.Width, $canvas.Height))
      $canvas.Arrange([Windows.Rect]::new(0, 0, $canvas.Width, $canvas.Height))
      $canvas.UpdateLayout()

      # Initialize RenderTargetBitmap correctly with dimensions
      $renderTargetBitmap = New-Object Windows.Media.Imaging.RenderTargetBitmap($canvas.Width, $canvas.Height, 96, 96, [Windows.Media.PixelFormats]::Pbgra32)

      # Render the canvas to the bitmap
      $renderTargetBitmap.Render($canvas)

      # Create a BitmapFrame from the RenderTargetBitmap
      $bitmapFrame = [Windows.Media.Imaging.BitmapFrame]::Create($renderTargetBitmap)

      # Create a PngBitmapEncoder and add the frame
      $bitmapEncoder = [Windows.Media.Imaging.PngBitmapEncoder]::new()
      $bitmapEncoder.Frames.Add($bitmapFrame)

      # Save to a memory stream
      $imageStream = New-Object System.IO.MemoryStream
      $bitmapEncoder.Save($imageStream)
      $imageStream.Position = 0

      # Load the stream into a BitmapImage
      $bitmapImage = [Windows.Media.Imaging.BitmapImage]::new()
      $bitmapImage.BeginInit()
      $bitmapImage.StreamSource = $imageStream
      $bitmapImage.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
      $bitmapImage.EndInit()

      return $bitmapImage
  } else {
      return $LogoViewbox
  }
}
