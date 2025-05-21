set(targetName Nes)

add_executable(${targetName})

target_sources(${targetName}
PRIVATE
        ./main.cpp

        ./parse/Header.cpp
        ./parse/Header.hpp
        ./parse/GameData.cpp
        ./parse/GameData.hpp

        ./NES/Cpu.hpp

        ./log/log.hpp
        ./types/types.hpp
)

target_include_directories(${targetName}
PUBLIC
        ./
        ./log
        ./types
)
