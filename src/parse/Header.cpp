#include "Header.hpp"

const char* RomFormat::repr() const {
    switch (self) {
        case Archaic:
            return "Archaic iNes";
        case Standard:
            return "iNes";
        case VersionTwo:
            return "iNes 2.0";
    }
}

std::ostream& operator<<(std::ostream& stream, const RomFormat& a) {
    stream << a.repr();
    return stream;
}
bool RomFormat::operator==(const RomFormat& o) {
    return self == o.self;
}
bool RomFormat::operator!=(const RomFormat& o) {
    return self != o.self;
}

const char* Arrangement::repr() const {
    switch (self) {
        case Horizontal:
            return "Horizontal";
        case Vertical:
            return "Vertical";
    }
}

std::ostream& operator<<(std::ostream& stream, const Arrangement& a) {
    stream << a.repr();
    return stream;
}
