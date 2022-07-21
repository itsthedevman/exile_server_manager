@echo off

cd build/receiver
cargo run --release -- ^
    --host esm.mshome.net:54321 ^
    --database-uri mysql://root:password12345@localhost:3306/exile_test_esm ^
    --a3-server-path E:\ArmaServers\ExileServerManager ^
    --a3-server-args="-mod=@Exile; -servermod=@ExileServer;@esm; -config=@ExileServer\config.cfg -port=2302 -profiles=ArmAServer -cfg=@ExileServer\basic.cfg -name=ArmAServer -autoinit -enableHT -loadMissionToMemory -world=empty -noSound -nosplash" ^
