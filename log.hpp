#pragma once

#define LOGGING 1
#if LOGGING
#include <iomanip>
#include <iostream>
#endif

#if LOGGING
#define LOG(expr) std::clog << #expr << ":\n\t" << expr << std::endl;
#define LOG_HEX(expr) \
    std::clog << #expr << ":\n\t" << std::hex << +expr << std::endl;
#else
#define LOG(expr) ;
#define LOG_HEX(expr) ;
#endif
