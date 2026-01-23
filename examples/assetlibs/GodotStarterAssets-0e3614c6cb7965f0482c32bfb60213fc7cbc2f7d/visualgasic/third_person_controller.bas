' Third Person Controller - Gasic Conversion
' All variable types are explicitly defined

Dim body_rotation_speed As Single
Dim max_pitch As Single
Dim min_pitch As Single
Dim camera_distance As Single
Dim camera_follow_speed As Single
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
Dim camera_arm As Object ' SpringArm3D
Dim camera As Object ' Camera3D
Dim body As Object ' Node3D

Sub _ready()
    camera_position = GetNode("CameraPosition")
    camera_gimbal = GetNode("CameraGimbal")
    camera_yaw = camera_gimbal.GetNode("Yaw")
    camera_pitch = camera_gimbal.GetNode("Yaw/Pitch")
    camera_arm = camera_gimbal.GetNode("Yaw/Pitch/SpringArm")
    camera = camera_gimbal.GetNode("Yaw/Pitch/SpringArm/Camera")
    body = GetNode("Body")
End Sub

Sub _unhandled_input(event As Object)
    If mouse_capture_on_click Then
        If Input.mouse_mode <> Input.MOUSE_MODE_CAPTURED Then
            If TypeOf event Is InputEventMouseButton Then
                If event.button_index = MOUSE_BUTTON_LEFT Then
                    Input.SetMouseMode(Input.MOUSE_MODE_CAPTURED)
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
