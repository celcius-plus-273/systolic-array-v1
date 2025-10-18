import numpy as np

def to_twos_comp(val, bytes=1):
    try:
        val_str = int(val).to_bytes(bytes, 'big', signed=True)
        return val_str.hex()
    except:
        val_str = int(val & 0xFF).to_bytes(bytes+1, 'big', signed=True)
        return val_str.hex()[0:bytes]

def from_twos_comp(val, bytes=1, format='h'):
    if format == 'b':
        bits = 2
    elif format =='h':
        bits = 16
    else:
        print(f"[ERROR]: Unknown format: {format}")
        exit(-1)

    unsgined_val = int(val, bits).to_bytes(bytes, 'big', signed=False)

    return int.from_bytes(unsgined_val, 'big', signed=True)

def to_bin(file, A, rows, cols, format='h'):
    # write memory to output format [bin/hex]
    f = open(file, 'w')
    for i in range(rows):
        for j in range(cols):
            # assert (A[i][j] <= 127 and A[i][j] >= -128) # saturate 8 bits
            val = to_twos_comp(A[i][j])
            f.write(f'{val}')
        f.write('\n')

# Converts a staggered matrix back into a non-staggered matrix
# Inputs
#   rows: row dimension of expected output matrix 
#   cols: col dimension of expected output matrix
def stagger_to_matrix(A, rows, cols):
    # input matrix A must have the following staggered matrix dimensions
    assert A.shape == (rows + cols - 1, cols)

    # revert a staggered matrix
    # i: row pointer
    # j: col pointer
    B = np.zeros((rows, cols), dtype=int)
    for j in range(cols):
        for i in range(j, rows+j):
            B[i-j][j] = A[i][j]
            
    return B

def matrix_to_stagger(A):
    # A must be a 2D array
    assert A.ndim == 2

    # extract the two dimensions
    rows, cols = A.shape

    # instantiate output array dimensions
    B = np.zeros((rows + cols - 1, cols), dtype=int)
    for j in range(cols):
        for i in range(j, rows+j):
            B[i][j] = A[i-j][j]
    
    return B

def vertical_flip(A):
    # A must be a 2D array
    assert A.ndim == 2
    return np.flip(A, 0)

def horizontal_flip(A):
    # A must be a 2D array
    assert A.ndim == 2
    return np.flip(A, 1)

def random_matrix(range, dim):
    return np.random.randint(range[0], range[1], dim)

def read_output_mem(file, rows, cols):
    B = np.zeros((rows + cols - 1, cols), dtype=int)
    f = open(file, 'r')
    lines = f.readlines()
    for i in range(rows + cols - 1):
        line = lines[i]
        # each line has #cols * 8 bits
        for j in range(cols):
            start = 2*j
            entry = line[start:start+2]
            if entry == 'xx':
                entry = '00'
            B[i][j] = from_twos_comp(entry)

    return stagger_to_matrix(horizontal_flip(B), rows, cols)

def read_golden(file, rows, cols):
    B = np.zeros((rows, cols), dtype=int)
    f = open(file, 'r')
    lines = f.readlines()
    for i in range(rows):
        line = lines[i]
        # each line has #cols * 8 bits
        for j in range(cols):
            start = 2*j
            end = (2*j) + 1
            entry = line[start:end+1]
            B[i][j] = from_twos_comp(entry)

    return B