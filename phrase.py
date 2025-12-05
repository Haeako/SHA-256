import hashlib

def string_to_sha256_blocks(input_string):
    """
    Format output: reg [511:0] phù hợp với tb_sha256.v
    """
    
    # Chuyển string sang bytes
    message_bytes = input_string.encode('utf-8')
    
    # Độ dài message tính bằng bits
    message_bit_length = len(message_bytes) * 8
    
    print("="*80)
    print(f"Input: \"{input_string}\"")
    print(f"Length: {len(message_bytes)} bytes ({message_bit_length} bits)")
    print("="*80)
    
    # Tạo padded message
    padded = bytearray(message_bytes)
    
    # Thêm bit 1 (0x80)
    padded.append(0x80)
    
    # Tính số byte cần padding
    current_length = len(padded)
    target_length = ((current_length + 8 + 63) // 64) * 64
    padding_needed = target_length - current_length - 8
    
    # Thêm các byte 0x00
    padded.extend([0x00] * padding_needed)
    
    # Thêm 8 bytes cho message length (big-endian)
    padded.extend(message_bit_length.to_bytes(8, byteorder='big'))
    
    # Chia thành các block 512-bit (64 bytes)
    num_blocks = len(padded) // 64
    blocks = []
    
    print(f"\nNumber of 512-bit b[{num_blocks}]\n")
    
    for i in range(num_blocks):
        block_start = i * 64
        block_end = block_start + 64
        block_bytes = padded[block_start:block_end]
        
        # Chuyển thành hex string
        block_hex = block_bytes.hex()
        
        # Format cho Verilog: chia thành 16 nhóm 32-bit (8 hex chars)
        formatted_parts = []
        for j in range(0, len(block_hex), 8):
            formatted_parts.append(block_hex[j:j+8])
        
        verilog_format = "".join(formatted_parts)
        blocks.append(verilog_format)
        
        # print(f"// Block {i}")
        print(f"b[{i}] = 512'h{verilog_format};")
        print()
    
    # Tính SHA-256 hash để verify
    sha256_hash = hashlib.sha256(message_bytes).hexdigest()
    
    print(f"// Expected SHA-256 hash:")
    print(f"expected = 256'h{sha256_hash};")
    print()
    
    return blocks, sha256_hash


# Test với các ví dụ
if __name__ == "__main__":
    test_cases = [
        "Truong dai hoc cong nghe thong tin"
    ]
    
    for test_str in test_cases:
        string_to_sha256_blocks(test_str)
        print("\n")