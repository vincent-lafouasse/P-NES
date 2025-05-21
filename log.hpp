#pragma once

#include <cstddef>

#define LOGGING 1
#if LOGGING
#include <iomanip>
#include <iostream>
#endif

#if LOGGING
#define LOG(expr) std::clog << #expr << ":\n\t" << expr << std::endl;
#define LOG_HEX(expr)             \
    std::clog << #expr << ":\n\t" \
              << "0x" << std::hex << +expr << std::endl;
#define LOG_NUM(expr) std::clog << #expr << ":\n\t" << +expr << std::endl;
#define LOG_BOOL(expr) \
    std::clog << #expr << ":\n\t" << static_cast<bool>(expr) << std::endl;
#else
#define LOG(expr) ;
#define LOG_HEX(expr) ;
#define LOG_NUM(expr) ;
#define LOG_BOOL(expr) ;
#endif
