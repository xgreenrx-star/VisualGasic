' First Person Controller - Gasic Conversion
' All variable types are explicitly defined

Dim max_pitch As Single
Dim min_pitch As Single
Dim mouse_capture_on_click As Boolean
Dim mouse_sensitivity As Single
Dim joystick_sensitivity As Single
Dim joystick_exp As Single
Dim walk_speed As Single
Dim run_speed As Single
Dim ground_acceleration As Single
Dim air_acceleration As Single
Dim jump_speed As Single
Dim camera_position As Object ' Marker3D
Dim camera_gimbal As Object ' Node3D
Dim camera_yaw As Object ' Node3D
Dim camera_pitch As Object ' Node3D
Dim body As Object ' Node3D

Sub _ready()
    ' Initialize camera and body
    camera_position = GetNode("CameraPosition")
    camera_gimbal = GetNode("CameraGimbal")
    camera_yaw = camera_gimbal.GetNode("Yaw")
    camera_pitch = camera_gimbal.GetNode("Yaw/Pitch")
    body = GetNode("Body")
End Sub

Sub _unhandled_input(event As Object)
    ' Mouse capture and release
    If mouse_capture_on_click Then
        If Input.mouse_mode <> Input.MOUSE_MODE_CAPTURED Then
            If TypeOf event Is InputEventMouseButton Then
                If event.button_index = MOUSE_BUTTON_LEFT Then
                    Input.SetMouseMode(Input.MOUSE_MODE_CAPTURED)
                End If
            End If
            If TypeOf event Is InputEventKey Then
                If event.IsActionPressed("ui_cancel") Then
                    Input.SetMouseMode(Input.MOUSE_MODE_VISIBLE)
                End If
            End If
        End If
    End If
    ' Mouse look
    If TypeOf event Is InputEventMouseMotion Then
        MouseLook(event)
    End If
End Sub

Sub MouseLook(event As Object)
    ' Implement mouse look logic here
End Sub
