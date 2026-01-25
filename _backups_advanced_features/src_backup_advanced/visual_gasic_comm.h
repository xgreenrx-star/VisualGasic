#ifndef VISUAL_GASIC_COMM_H
#define VISUAL_GASIC_COMM_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

// Linux specific headers for real serial implementation
// #ifdef __linux__
// #include <fcntl.h>
// #include <termios.h>
// #include <unistd.h>
// #include <errno.h>
// #endif

using namespace godot;

class MSComm : public RefCounted {
    GDCLASS(MSComm, RefCounted);

    int comm_port;
    String settings;
    int handshaking;
    bool port_open;
    // int fd; // File descriptor for Linux

protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("set_comm_port", "p_port"), &MSComm::set_comm_port);
        ClassDB::bind_method(D_METHOD("get_comm_port"), &MSComm::get_comm_port);
        ClassDB::bind_method(D_METHOD("set_settings", "p_settings"), &MSComm::set_settings);
        ClassDB::bind_method(D_METHOD("get_settings"), &MSComm::get_settings);
        ClassDB::bind_method(D_METHOD("set_handshaking", "p_hand"), &MSComm::set_handshaking);
        ClassDB::bind_method(D_METHOD("get_handshaking"), &MSComm::get_handshaking);
        
        ClassDB::bind_method(D_METHOD("set_is_open", "p_open"), &MSComm::set_is_open);
        ClassDB::bind_method(D_METHOD("get_is_open"), &MSComm::get_port_open);
        
        ClassDB::bind_method(D_METHOD("set_port_open", "p_open"), &MSComm::set_is_open);
        ClassDB::bind_method(D_METHOD("get_port_open"), &MSComm::get_port_open);
        
        ClassDB::bind_method(D_METHOD("Open"), &MSComm::open);
        ClassDB::bind_method(D_METHOD("Close"), &MSComm::close);

        ClassDB::bind_method(D_METHOD("set_output", "p_out"), &MSComm::set_output);
        ClassDB::bind_method(D_METHOD("get_input"), &MSComm::get_input);

        ADD_PROPERTY(PropertyInfo(Variant::INT, "CommPort"), "set_comm_port", "get_comm_port");
        ADD_PROPERTY(PropertyInfo(Variant::STRING, "Settings"), "set_settings", "get_settings");
        ADD_PROPERTY(PropertyInfo(Variant::INT, "Handshaking"), "set_handshaking", "get_handshaking");
        ADD_PROPERTY(PropertyInfo(Variant::BOOL, "PortOpen"), "set_port_open", "get_port_open");
        ADD_PROPERTY(PropertyInfo(Variant::BOOL, "IsOpen"), "set_is_open", "get_is_open");
        // Output is Write-Only/Method in some contexts, but property here
        // Input is Read-Only
    }

public:
    MSComm() {
        comm_port = 1;
        settings = "9600,N,8,1";
        handshaking = 0;
        port_open = false;
        // fd = -1;
    }

    ~MSComm() {
        if (port_open) close_port();
    }

    void set_comm_port(int p) { comm_port = p; }
    int get_comm_port() { return comm_port; }

    void set_settings(String s) { settings = s; }
    String get_settings() { return settings; }

    void set_handshaking(int h) { handshaking = h; }
    int get_handshaking() { return handshaking; }

    void set_is_open(bool p_open) {
        if (p_open == port_open) return;
        
        if (p_open) {
            open_port();
            port_open = true;
        } else {
            close_port();
            port_open = false;
        }
    }

    void open() {
        open_port();
        port_open = true;
    }

    void close() {
        close_port();
        port_open = false;
    }


    bool get_port_open() { return port_open; }

    void set_output(String data) {
        if (!port_open) return;
// #ifdef __linux__
//         if (fd >= 0) {
//             CharString cs = data.utf8();
//             write(fd, cs.get_data(), cs.length());
//         }
// #else
        UtilityFunctions::print("Mock Serial Write: ", data);
// #endif
    }

    String get_input() {
        if (!port_open) return "";
        String ret = "";
// #ifdef __linux__
//         if (fd >= 0) {
//             char buf[256];
//             int n = read(fd, buf, sizeof(buf)-1);
//             if (n > 0) {
//                 buf[n] = 0;
//                 ret = String::utf8(buf);
//             }
//         }
// #endif
        return ret;
    }

private:
    bool open_port() {
        UtilityFunctions::print("MSComm: Simulation Mode Open");
        return true;
        
// #ifdef __linux__
//         // For safety in this environment, enable simulation by default for low ports
//         if (comm_port < 100) {
//              // UtilityFunctions::print("MSComm: Simulation Mode");
//              return true;
//         }

//         String dev = "/dev/ttyS" + String::num_int64(comm_port - 1); // rough mapping COM1 -> ttyS0? Or ttyUSB0?
//         // Let's try ttyUSB first if > 0, actually typical linux mapping is simpler to just guess or map 1->USB0
//         if (comm_port == 1) dev = "/dev/ttyUSB0"; // Common adapter
//         else dev = "/dev/ttyS" + String::num_int64(comm_port - 1);
        
//         // For testing in this environment without real hardware, we might fail.
//         // We will fallback to "Fake Mode" if open fails, so the user script runs.
        
//         fd = open(dev.utf8().get_data(), O_RDWR | O_NOCTTY | O_NDELAY);
//         if (fd == -1) {
//             UtilityFunctions::print("MSComm: Failed to open ", dev, " (", errno, "). Switch to Simulation mode.");
//             return true; // Simulate success
//         } else {
//             fcntl(fd, F_SETFL, 0);
//             UtilityFunctions::print("MSComm: Opened ", dev);
//             return true;
//         }
// #endif
//         UtilityFunctions::print("MSComm: Simulation Open COM", comm_port);
//         return true;
    }

    void close_port() {
// #ifdef __linux__
//         if (fd != -1) {
//             close(fd);
//             fd = -1;
//         }
// #endif
        UtilityFunctions::print("MSComm: Closed Port");
    }
};

#endif
