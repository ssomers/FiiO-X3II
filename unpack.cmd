for %%v in (1.4 2.0) do (
    if exist unpacked_%%v rmdir /Q/S unpacked_%%v
    pack\packtools --unpack -i %%v\X3II.fw -o unpacked_%%v
)
