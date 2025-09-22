# generate_data.py
import os
import sys
import random
import math
import numpy as np

output_dir                  =   "../../src/vcs/tb/test_vec"
input_data_ws_path          =   output_dir + "/peArr_inputMatrix_data_ws.txt" 
input_data_shifted_ws_path  =   output_dir + "/peArr_inputMatrix_data_shifted_ws.txt" 
weights_data_ws_path        =   output_dir + "/peArr_weightMatrix_data_ws.txt" 
weights_data_shifted_ws_path=   output_dir + "/peArr_weightMatrix_data_shifted_ws.txt" 
weights_data_flip_ws_path   =   output_dir + "/peArr_weightMatrix_data_flip_ws.txt" 
output_data_ws_path         =   output_dir + "/peArr_output_data_ws.txt" 
output_data_shifted_ws_path =   output_dir + "/peArr_output_data_shifted_ws.txt" 
ctrl_data_ws_path           =   output_dir + "/peArr_ctrl_data_ws.txt" 
ctrl_data_shifted_ws_path   =   output_dir + "/peArr_ctrl_data_shifted_ws.txt" 
psum_data_ws_path           =   output_dir + "/peArr_pSum_data_ws.txt" 
psum_data_shifted_ws_path   =   output_dir + "/peArr_pSum_data_shifted_ws.txt" 
accum_data_ws_path          =   output_dir + "/peArr_accum_data_ws.txt" 
accum_data_shifted_ws_path  =   output_dir + "/peArr_accum_data_shifted_ws.txt" 

#unused
def shift_rows(matrix):
    expanded_matrix = np.zeros((matrix.shape[0], matrix.shape[1] + matrix.shape[0] - 1), dtype=matrix.dtype)
    for i in range(matrix.shape[0]):
        expanded_matrix[i, i:matrix.shape[1]+i] = matrix[i]
    return expanded_matrix

#generate skew for inputs
def shift_columns(matrix):
    expanded_matrix = np.zeros((matrix.shape[0] + matrix.shape[1] - 1, matrix.shape[1]), dtype=matrix.dtype)
    for j in range(matrix.shape[1]):
        expanded_matrix[j:matrix.shape[0]+j, j] = matrix[:, j]
    return expanded_matrix

def write_dma(matrix,file):
    for row in matrix:
        result = 0
        shift_amount = 0  # Initialize the shift amount
        for number in row:
            # Extract the first 8 bits and shift them to their position in the result
            result |= (number & ((1 << width) - 1)) << shift_amount
            shift_amount += width  # Increment the shift amount for the next number
        file.write(str(result)+'\n')

def truncate(value, min_value, max_value):
    if (value > max_value):
        value  = max_value
    if (value < min_value):
        value  = min_value

    return value

def shift_columns_expand(matrix):
    rows, cols = matrix.shape
    out = np.zeros((rows + cols - 1, cols), dtype=matrix.dtype)  # expand rows
    
    for j in range(cols):
        shift = j
        out[shift:shift+rows, j] = matrix[:, j]
    
    return out

def pad_columns(mat, left=1, right=1, value=0):
    rows, cols = mat.shape
    # make left and right zero-blocks
    left_block = np.full((rows, left), value, dtype=mat.dtype)
    right_block = np.full((rows, right), value, dtype=mat.dtype)
    # concatenate
    return np.hstack((left_block, mat, right_block))

def pad_rows(mat, top=1, bottom=0, value=0):
    rows, cols = mat.shape
    top_block = np.full((top, cols), value, dtype=mat.dtype)
    bottom_block = np.full((bottom, cols), value, dtype=mat.dtype)
    return np.vstack((top_block, mat, bottom_block))

def generate_data_ws(num_matrix,width,max_K,max_N,signed):
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    with open(input_data_ws_path, "w") as file_i:
        with open(weights_data_ws_path, "w") as file_w:
            with open(output_data_ws_path, "w") as file_o:
                with open(ctrl_data_ws_path, "w") as file_ctrl:
                    with open(psum_data_ws_path, "w") as file_pSum:
                        with open(accum_data_ws_path, "w") as file_accum:
                            with open(input_data_shifted_ws_path, "w") as file_i_shift:
                                with open(output_data_shifted_ws_path, "w") as file_o_shift:
                                    with open(accum_data_shifted_ws_path, "w") as file_accum_shift:
                                        with open(psum_data_shifted_ws_path, "w") as file_pSum_shift:
                                            with open(ctrl_data_shifted_ws_path, "w") as file_ctrl_shift:
                                                with open(weights_data_shifted_ws_path, "w") as file_w_shift:
                                                    with open(weights_data_flip_ws_path, "w") as file_w_flip:
                                                        weightOffset = 0
                                                        pSumOffset = 0
                                                        outOffset = 0
                                                        inputOffset = 0
                                                        inputOffset_shift = 0
                                                        pSumOffset_shift = 0
                                                        outOffset_shift = 0
                                                        weightOffset_shift = 0

                                                        if (signed > 0):
                                                            width = width-1
                                                        
                                                        max_value = 2 ** (width)-1

                                                        for i in range(num_matrix):
                                                            # T   = random.randint(1,i_size//num_matrix)
                                                            # SR  = random.randint(1,min(max_K,w_size//num_matrix))
                                                            # SC  = random.randint(1,max_N)
                                                            T = i_size
                                                            SR = max_K
                                                            SC = max_N
                                                            T_shift = max(T-1+SR-1, T-1+SC-1)
                                                            max_value_no_overflow = math.sqrt((2 ** (width)-1)/SC/2)
                                                            
                                                            if (signed > 0):
                                                                min_value = -max_value-1
                                                                min_value_no_overflow = -max_value_no_overflow
                                                            else:
                                                                min_value = 0
                                                                min_value_no_overflow = 0
                                                            
                                                            if(random.randint(0,10)<3):
                                                                random_matrixA      = np.random.randint(min_value, max_value, size=(T, SR))
                                                                random_matrixB      = np.random.randint(min_value, max_value, size=(SR, SC))
                                                                random_matrixPSum   = np.random.randint(min_value, max_value, size=(T, SC))
                                                            else:
                                                                random_matrixA      = np.random.randint(min_value_no_overflow, max_value_no_overflow, size=(T, SR))
                                                                random_matrixB      = np.random.randint(min_value_no_overflow, max_value_no_overflow, size=(SR, SC))
                                                                random_matrixPSum   = np.random.randint(min_value_no_overflow, max_value//2, size=(T, SC))

                                                            result_matrix = np.zeros((T, SC), dtype=int)
                                                            for j in range(T):   
                                                                for k in range(SC):
                                                                    for m in range(SR):
                                                                        multiplication      = random_matrixA[j][m] * random_matrixB[m][k]
                                                                        multiplication      = truncate ( multiplication, min_value, max_value )
                                                                        result_matrix[j][k] = result_matrix[j][k] + multiplication
                                                                        result_matrix[j][k] = truncate ( result_matrix[j][k], min_value, max_value )
                                                            
                                                            accum_matrix    = np.zeros((T, SC), dtype=int)
                                                            for j in range(len(result_matrix)):   
                                                                for k in range(len(result_matrix[0])):
                                                                    accum_matrix[j][k]  = result_matrix[j][k] + random_matrixPSum[j][k]
                                                                    accum_matrix[j][k]  = truncate ( accum_matrix[j][k] , min_value, max_value )
                                                            
                                                            # result_matrix           = np.dot(random_matrixA, random_matrixB)
                                                            # accum_matrix            = np.zeros((T, SC), dtype=int)

                                                            # indices                 = result_matrix > max_value
                                                            # result_matrix[indices]  = max_value

                                                            # indices                 = result_matrix < min_value
                                                            # result_matrix[indices]  = min_value
                                                            
                                                            # for j in range(len(result_matrix)):   
                                                            #     for k in range(len(result_matrix[0])):
                                                            #         accum_matrix[j][k] = result_matrix[j][k] + random_matrixPSum[j][k]
                                                            # indices = accum_matrix > max_value
                                                            # accum_matrix[indices] = max_value

                                                            for row in random_matrixPSum:
                                                                file_pSum.write(' '.join(map(str, row)) + '\n')
                                                            file_pSum.write(' '.join(map(str, np.full(SC, -1))) + '\n')

                                                            for row in accum_matrix:
                                                                file_accum.write(' '.join(map(str, row)) + '\n')
                                                            file_accum.write(' '.join(map(str, np.full(SC, -1))) + '\n')

                                                            for row in random_matrixA:
                                                                file_i.write(' '.join(map(str, row)) + '\n')
                                                            file_i.write(' '.join(map(str, np.full(SR, -1))) + '\n')

                                                            for row in result_matrix:
                                                                file_o.write(' '.join(map(str, row)) + '\n')
                                                            file_o.write(' '.join(map(str, np.full(SC, -1))) + '\n')

                                                            for row in random_matrixB:
                                                                file_w.write(' '.join(map(str, row)) + '\n')
                                                            file_w.write(' '.join(map(str, np.full(SC, -1))) + '\n')

                                                            # zero pad weights
                                                            random_matrixB_shifted = pad_columns (random_matrixB, left= 0, right=max_N-SC )                                    
                                                            random_matrixB_shifted = pad_rows (random_matrixB_shifted, top=max_K-SR, bottom= 0 )           
                                                            for row in random_matrixB_shifted:
                                                                file_w_shift.write(' '.join(map(str, row)) + '\n')
                                                            file_w_shift.write(' '.join(map(str, np.full(max_N, -1))) + '\n')

                                                            # shifting inputs
                                                            random_matrixA_shifted = shift_columns_expand (random_matrixA)                                    
                                                            random_matrixA_shifted = pad_columns (random_matrixA_shifted, left= max_N-SR, right=0 )                                    
                                                            if (SR < SC):
                                                                random_matrixA_shifted = pad_rows (random_matrixA_shifted, top=0, bottom= SC-SR )
                                                            for row in random_matrixA_shifted:
                                                                file_i_shift.write(' '.join(map(str, row)) + '\n')
                                                            file_i_shift.write(' '.join(map(str, np.full(max_K, -1))) + '\n')

                                                            # shifting outputs
                                                            result_matrix_shifted = shift_columns_expand (result_matrix)
                                                            result_matrix_shifted = pad_columns (result_matrix_shifted, left= 0, right=max_N-SC )                                    
                                                            for row in result_matrix_shifted:
                                                                file_o_shift.write(' '.join(map(str, row)) + '\n')
                                                            file_o_shift.write(' '.join(map(str, np.full(max_N, -1))) + '\n')

                                                            # shifting partial sum
                                                            random_matrixPSum_shifted = shift_columns_expand (random_matrixPSum)
                                                            random_matrixPSum_shifted = pad_columns (random_matrixPSum_shifted, left= 0, right=max_N-SC )                                    
                                                            for row in random_matrixPSum_shifted:
                                                                file_pSum_shift.write(' '.join(map(str, row)) + '\n')
                                                            file_pSum_shift.write(' '.join(map(str, np.full(max_N, -1))) + '\n')

                                                            # shifting outputs
                                                            accum_matrix_shifted = shift_columns_expand (accum_matrix)
                                                            accum_matrix_shifted = pad_columns (accum_matrix_shifted, left= 0, right=max_N-SC )                                    
                                                            for row in accum_matrix_shifted:
                                                                file_accum_shift.write(' '.join(map(str, row)) + '\n')
                                                            file_accum_shift.write(' '.join(map(str, np.full(max_N, -1))) + '\n')

                                                            random_matrixB_flip = np.flipud(random_matrixB_shifted)
                                                            for row in random_matrixB_flip:
                                                                file_w_flip.write(' '.join(map(str, row)) + '\n')
                                                            file_w_flip.write(' '.join(map(str, np.full(max_N, -1))) + '\n')


                                                            print(random_matrixA)
                                                            print(random_matrixB)
                                                            print(result_matrix)
                                                            
                                                            pSum_lenght_shift, cols = result_matrix_shifted.shape
                                                            pSum_lenght_shift       = pSum_lenght_shift - 1

                                                            file_ctrl.write(f"{T-1} {SR-1} {SC-1} {inputOffset} {weightOffset} {pSumOffset} {outOffset}\n")
                                                            # file_ctrl_shift.write(f"{T-1+SR-1} {max_K-1} {max_N-1} {inputOffset_shift} {weightOffset} {pSumOffset_shift} {outOffset_shift}\n")
                                                            file_ctrl_shift.write(f"{T_shift} {SR-1} {SC-1} {inputOffset_shift} {weightOffset_shift} {pSumOffset_shift} {outOffset_shift} {pSum_lenght_shift}\n")
                                                            inputOffset         +=T
                                                            weightOffset        +=SR
                                                            pSumOffset          +=T
                                                            outOffset           +=T
                                                            inputOffset_shift   +=T_shift
                                                            pSumOffset_shift    +=pSum_lenght_shift
                                                            outOffset_shift     +=T+SC-1
                                                            weightOffset_shift  +=max_K


if __name__ == "__main__":
    
    num_matrix  = int(sys.argv[1])
    width       = int(sys.argv[2])
    num_row     = int(sys.argv[3])
    num_col     = int(sys.argv[4])
    w_size      = int(sys.argv[5])
    i_size      = int(sys.argv[6])
    signed      = int(sys.argv[7])
    generate_data_ws(num_matrix,width,num_row,num_col,signed)
