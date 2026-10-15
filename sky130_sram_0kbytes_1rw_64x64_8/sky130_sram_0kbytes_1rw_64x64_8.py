word_size = 64 # Bits (64 bits per word)
num_words = 64 # 64 addressable words
words_per_row = 1 
human_byte_size = "{:.0f}kbytes".format((word_size * num_words) / 8 / 1024)


# Allow byte writes
write_size = 8 # Bits

# Dual port
num_rw_ports = 1
num_r_ports = 0
num_w_ports = 0
ports_human = '1rw'

num_spare_cols = 5 # Can also be reproduced with smaller numbers
num_spare_rows = 5 # Can also be reproduced with smaller numbers

import os
file_path = "/home/adamsbane/project_digital/librelane/OpenRAM/macros/sram_configs/sky130_sram_common.py"
exec(open(file_path).read())
