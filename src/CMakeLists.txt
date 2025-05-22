set(targetName Nes)

add_executable(${targetName})

target_sources(${targetName}
PRIVATE
        ./main.cpp

		Cartridge/Cartridge.cpp
		Cartridge/Cartridge.hpp
		Cartridge/Header.cpp
		Cartridge/Header.hpp

		Cpu/Cpu.cpp
		Cpu/Cpu.hpp
		Cpu/Instruction.hpp

		Bus/Bus.hpp

        ./log/log.hpp
        ./types/types.hpp
)

target_include_directories(${targetName}
PUBLIC
        ./
        ./log
        ./types
)
