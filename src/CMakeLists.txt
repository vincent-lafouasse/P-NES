set(targetName Nes)

add_executable(${targetName})

target_sources(${targetName}
PRIVATE
        ./main.cpp

		Cartridge/Header.cpp
		Cartridge/Header.hpp
		Cartridge/Cartridge.cpp
		Cartridge/Cartridge.hpp

		Cpu/Cpu.hpp

        ./log/log.hpp
        ./types/types.hpp
)

target_include_directories(${targetName}
PUBLIC
        ./
        ./log
        ./types
)
