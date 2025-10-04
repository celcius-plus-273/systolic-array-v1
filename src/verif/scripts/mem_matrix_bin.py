import numpy as np

def to_bin(file, A, rows, cols, format='h'):
    # write memory to output format [bin/hex]
    f = open(file, 'w')
    for i in range(rows):
        for j in range(cols):
            assert A[i][j] < 128 # saturate 8 bits
            f.write(f'{A[i][j]:02x}')
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

def read_output_mem(file, rows, cols):
    B = np.zeros((rows + cols - 1, cols), dtype=int)
    f = open(file, 'r')
    lines = f.readlines()
    for i in range(rows + cols - 1):
        assert len(line) == 8
        # each line has #cols * 8 bits
        for j in range(cols):
            entry = line[j, j+1]
            B[i][j] = int(entry)

    return B

def horizontal_flip(A):
    # A must be a 2D array
    assert A.ndim == 2

    # extract the two dimensions
    rows, cols = A.shape

    B = np.zeros((rows, cols), dtype=int)
    for i in range(rows-1, -1, -1):
        B[(rows - 1) - i] = A[i]

    return B

def random_matrix(range, dim):
    return np.random.randint(range[0], range[1], dim)

def main():
    K = 4
    M = 4
    N = 4

    # need to generate 4x4 weight matrix and 4x4 input matrix (with staggering)
    low = 1
    high = 8
    weight_matrix = random_matrix((low, high), (K, N))
    input_matrix = random_matrix((low, high), (M, K))
    stag_input_matrix = matrix_to_stagger(input_matrix)

    output_matrix = np.matmul(input_matrix, weight_matrix)

    to_bin('bin/weight_rom.hex', horizontal_flip(weight_matrix), K, N)
    to_bin('bin/input_rom.hex', stag_input_matrix, M + K -1, K)

    to_bin('bin/output_golden.hex', output_matrix, M, N)


if __name__ == '__main__':
    main()