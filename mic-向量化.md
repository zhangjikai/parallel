# 向量化
<!-- toc -->
## 前言
向量化简单的说就是使用SIMD指令, 来实现使用一条指令同时处理多个数据, MIC中具有32个长度为512位的向量处理单元, 每个向量处理单元可以处理16个32位或者8个64位的数据. 这里主要记录一下MIC向量化的使用方式以及一些向量指令的作用.

## 数据类型
MIC中使用下面的数据类型作为执行向量函数的操作数
```c
__m512, __m512i  __m512d
```
下面是它们的各自的作用:
* `__m512` - 处理单精度向量(float32 vector)
* `__m512d` - 处理双精度向量(float64 vector)
* `__m512i` - 处理整形向量, 包括32位和64位整形(int32/int64)

上面的数据类型直接映射到向量寄存器上(vector registers), 除此之外还有一种数据类型__mmask16 - is an unsigned short type associated with the mask register values.
我们可以使用 `Load Intrinsics`(为向量赋值) 和 `Store Intrinsics` (保存向量的值) 实现向量的存取. 下面是一个示例
```c
void test_load_store() {

    // 使用int32_t和int64_t 需要引入stdint.h
    int32_t *arr_int32;
    int64_t *arr_int64;
    int i, n = 32;

    // 需要使用_mm_malloc分配内存, 并且以64位对齐, 否则可能出现错误
    arr_int32 = _mm_malloc(sizeof(int32_t) * n, 64);
    arr_int64 = _mm_malloc(sizeof(int64_t) * n, 64);

    for(i = 0; i < n; i++) {
        arr_int32[i] = i;
        arr_int64[i] = i + n;
    }

#pragma offload target(mic) inout(arr_int32:length(n)) inout(arr_int64:length(n))
    {
        __m512i m_32, m_64;
        // 将arr_int32 中0-15个元素加载到 m_32 中
        m_32 = _mm512_load_epi32(arr_int32);
        // 将arr_int32 中16-31个元素加载到 m_32 中
        m_32 = _mm512_load_epi32(arr_int32 + 16);

        // 将arr_int64中0-7个元素加载到 m_64 中
        m_64 = _mm512_load_epi64(arr_int64);
        // 将arr_int64中8-15个元素加载到 m_64 中
        m_64 = _mm512_load_epi64(arr_int64 + 8);

        // 将m_32 中的值保存到arr_int32 的0-15个元素中
        _mm512_store_epi32(arr_int32, m_32);
        // 将m_64 中的值保存到arr_int32 的16-31个元素中
        _mm512_store_epi32(arr_int32 + 16, m_32);

        // 将m_64 中的值保存到arr_int64的0-7个元素
        _mm512_store_epi64(arr_int64, m_64);
        // 将m_64 中的值保存到arr_int64的8-15个元素中
        _mm512_store_epi64(arr_int64 + 8, m_64);
    }

    // 使用_mm_malloc分配的内存需要_mm_free来释放
    _mm_free(arr_int32);
    _mm_free(arr_int64);
}
```
## 向量化函数(Intrinsics)
这里主要记录一些编译器提供的向量化函数, 完整的函数集可以在[这里](https://software.intel.com/en-us/node/523386)或者[这里](http://scc.ustc.edu.cn/zlsc/tc4600/intel/2015.1.133/compiler_c/)查询
### 算术运算
MIC中提供了加,减, 乘 三种算术运算函数, 这里以32位整型的加法为例:
```c
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <immintrin.h>

void mic_add() {
    uint32_t *arr_a, *arr_b, *arr_c;
    int i = 0, n = 16;

    arr_a = _mm_malloc(sizeof(uint32_t) * n, 64);
    arr_b = _mm_malloc(sizeof(uint32_t) * n, 64);
    arr_c = _mm_malloc(sizeof(uint32_t) * n, 64);

    for(i = 0; i < n; i++) {
        arr_a[i] = i;
        arr_b[i] = n + i;
    }

#pragma offload target(mic) in(arr_a:length(n)) in(arr_b:length(n)) out(arr_c:length(n))
    {
        __m512i m_a, m_b, m_c;
        m_a = _mm512_load_epi32(arr_a);
        m_b = _mm512_load_epi32(arr_b);
        m_c = _mm512_add_epi32(m_a, m_b);

        // 减法
        //m_c = _mm512_sub_epi32(m_a, m_b);

        // 乘法 _mm512_mullo_epi32 保留乘法结果的低32位, _mm512_mulhi_epi32保存结果的高32位
        // m_c = _mm512_mullo_epi32(m_a, m_b);
        _mm512_store_epi32(arr_c, m_c);
    }

    for(i = 0; i < n; i++) {
        printf("arr_a[%2d] is: %2d \t  arr_b[%2d] is: %2d \t  arr_c[%2d] is : %2d\n", i, arr_a[i], i, arr_b[i], i, arr_c[i]);
    }
    _mm_free(arr_a);
    _mm_free(arr_b);
    _mm_free(arr_c);
}

int main() {
    mic_add();
}
```
输出结果为:
```html
arr_a[ 0] is:  0 	  arr_b[ 0] is: 16 	  arr_c[ 0] is : 16
arr_a[ 1] is:  1 	  arr_b[ 1] is: 17 	  arr_c[ 1] is : 18
arr_a[ 2] is:  2 	  arr_b[ 2] is: 18 	  arr_c[ 2] is : 20
arr_a[ 3] is:  3 	  arr_b[ 3] is: 19 	  arr_c[ 3] is : 22
arr_a[ 4] is:  4 	  arr_b[ 4] is: 20 	  arr_c[ 4] is : 24
arr_a[ 5] is:  5 	  arr_b[ 5] is: 21 	  arr_c[ 5] is : 26
arr_a[ 6] is:  6 	  arr_b[ 6] is: 22 	  arr_c[ 6] is : 28
arr_a[ 7] is:  7 	  arr_b[ 7] is: 23 	  arr_c[ 7] is : 30
arr_a[ 8] is:  8 	  arr_b[ 8] is: 24 	  arr_c[ 8] is : 32
arr_a[ 9] is:  9 	  arr_b[ 9] is: 25 	  arr_c[ 9] is : 34
arr_a[10] is: 10 	  arr_b[10] is: 26 	  arr_c[10] is : 36
arr_a[11] is: 11 	  arr_b[11] is: 27 	  arr_c[11] is : 38
arr_a[12] is: 12 	  arr_b[12] is: 28 	  arr_c[12] is : 40
arr_a[13] is: 13 	  arr_b[13] is: 29 	  arr_c[13] is : 42
arr_a[14] is: 14 	  arr_b[14] is: 30 	  arr_c[14] is : 44
arr_a[15] is: 15 	  arr_b[15] is: 31 	  arr_c[15] is : 46
```
### With Mask
MIC提供的向量函数一般有两种形式
```c
// Without Mask
extern _m512i __cdecl _mm512_add_epi32(_m512i v2, _m512i v3);

// With Mask
extern _m512i __cdecl _mm512_mask_add_epi32(_m512i v1_old, __mmask16 k1, _m512i v2, _m512i v3);
```
一种是带Mask的, 一种是不带Mask的. 带Mask的多了两个参数: `v1_old`和`k1`, 其中`k1`是`__mmask16`类型的数据, 在上面我们知道`__mmask`类型就是`unsigned short`类型, 长度为16位. 关于带mask函数的解释: 将`v1`的16位分别对应到`_m512i`的16个整型上, 如果`k1`某个位是1, 则将v2和v3中与该位对应的整型相加, 作为结果值, 如果`k1`某个位为0, 就使用`v1_old`向量中对应位的整型作为结果值. 例如如果`k1`的第一位为1, 那么就将`v2`的第一个整数和`v3`的第一个整数相加, 作为结果向量的第一个整型的值. 如果`k1`的第一位是0, 就将`v1_old`向量中的第一个整型的值作为结果向量中第一个整型的值. 好吧, 还是看个例子吧.
```c
void mic_mask_add() {
    uint32_t *arr_a, *arr_b, *arr_c, *arr_old;
    int i = 0, n = 16;

    arr_a = _mm_malloc(sizeof(uint32_t) * n, 64);
    arr_b = _mm_malloc(sizeof(uint32_t) * n, 64);
    arr_c = _mm_malloc(sizeof(uint32_t) * n, 64);
    arr_old = _mm_malloc(sizeof(uint32_t) * n, 64);

    for(i = 0; i < n; i++) {
        arr_a[i] = i;
        arr_b[i] = n + i;
        arr_old[i] = 10000;
    }

#pragma offload target(mic) in(arr_a:length(n)) in(arr_b:length(n)) in(arr_old:length(n)) out(arr_c:length(n))
    {
        __m512i m_a, m_b, m_c, m_old;
        // 11换成二进制就是0000000000001011
        __mmask16 k1 = 11;
        m_a = _mm512_load_epi32(arr_a);
        m_b = _mm512_load_epi32(arr_b);
        m_old = _mm512_load_epi32(arr_old);
        // 根据k1的值只有1,2,4位为1 所以m_c中只有第1,2,4个元素为m_a 和m_b中1,2,4个元素的和 剩余元素使用arr_old对应元素的值
        m_c = _mm512_mask_add_epi32(m_old, k1, m_a, m_b);
        _mm512_store_epi32(arr_c, m_c);
    }

    for(i = 0; i < n; i++) {
        printf("arr_a[%2d] is: %2d \t  arr_b[%2d] is: %2d \t arr_old[%2d] is: %d \t  arr_c[%2d] is : %2d\n", i, arr_a[i], i, arr_b[i], i, arr_old[i], i, arr_c[i]);
    }
    _mm_free(arr_a);
    _mm_free(arr_b);
    _mm_free(arr_c);
    _mm_free(arr_old);
}

```
运行结果为:
```html
arr_a[ 0] is:  0 	  arr_b[ 0] is: 16 	 arr_old[ 0] is: 10000 	  arr_c[ 0] is : 16
arr_a[ 1] is:  1 	  arr_b[ 1] is: 17 	 arr_old[ 1] is: 10000 	  arr_c[ 1] is : 18
arr_a[ 2] is:  2 	  arr_b[ 2] is: 18 	 arr_old[ 2] is: 10000 	  arr_c[ 2] is : 10000
arr_a[ 3] is:  3 	  arr_b[ 3] is: 19 	 arr_old[ 3] is: 10000 	  arr_c[ 3] is : 22
arr_a[ 4] is:  4 	  arr_b[ 4] is: 20 	 arr_old[ 4] is: 10000 	  arr_c[ 4] is : 10000
arr_a[ 5] is:  5 	  arr_b[ 5] is: 21 	 arr_old[ 5] is: 10000 	  arr_c[ 5] is : 10000
arr_a[ 6] is:  6 	  arr_b[ 6] is: 22 	 arr_old[ 6] is: 10000 	  arr_c[ 6] is : 10000
arr_a[ 7] is:  7 	  arr_b[ 7] is: 23 	 arr_old[ 7] is: 10000 	  arr_c[ 7] is : 10000
arr_a[ 8] is:  8 	  arr_b[ 8] is: 24 	 arr_old[ 8] is: 10000 	  arr_c[ 8] is : 10000
arr_a[ 9] is:  9 	  arr_b[ 9] is: 25 	 arr_old[ 9] is: 10000 	  arr_c[ 9] is : 10000
arr_a[10] is: 10 	  arr_b[10] is: 26 	 arr_old[10] is: 10000 	  arr_c[10] is : 10000
arr_a[11] is: 11 	  arr_b[11] is: 27 	 arr_old[11] is: 10000 	  arr_c[11] is : 10000
arr_a[12] is: 12 	  arr_b[12] is: 28 	 arr_old[12] is: 10000 	  arr_c[12] is : 10000
arr_a[13] is: 13 	  arr_b[13] is: 29 	 arr_old[13] is: 10000 	  arr_c[13] is : 10000
arr_a[14] is: 14 	  arr_b[14] is: 30 	 arr_old[14] is: 10000 	  arr_c[14] is : 10000
arr_a[15] is: 15 	  arr_b[15] is: 31 	 arr_old[15] is: 10000 	  arr_c[15] is : 10000
```
### Bitwise运算
MIC中提供了3中Bitwise运算函数- `and` `or` `xor`,  其中取反元素可以通过与1异或来实现, 下面是`and`操作的一个例子
```c
void mic_and() {
    uint32_t *arr_a, *arr_b, *arr_c;
    int i = 0, n = 16;

    arr_a = _mm_malloc(sizeof(uint32_t) * n, 64);
    arr_b = _mm_malloc(sizeof(uint32_t) * n, 64);
    arr_c = _mm_malloc(sizeof(uint32_t) * n, 64);

    for(i = 0; i < n; i++) {
        arr_a[i] = i ;
        arr_b[i] = n + i;
    }

#pragma offload target(mic) in(arr_a:length(n)) in(arr_b:length(n)) out(arr_c:length(n))
    {
        __m512i m_a, m_b, m_c;
        m_a = _mm512_load_epi32(arr_a);
        m_b = _mm512_load_epi32(arr_b);
        m_c = _mm512_and_epi32(m_a, m_b);

        // or
        // m_c = _mm512_or_epi32(m_a, m_b);

        // xor
        // m_c = _mm512_xor_epi32(m_a, m_b);
        _mm512_store_epi32(arr_c, m_c);
    }

    for(i = 0; i < n; i++) {
        print_binary (arr_a[i], 8);
        printf( " & ");
        print_binary(arr_b[i], 8);
        printf (" = ");
        print_binary(arr_c[i], 8);
        printf("\n");

    }
    _mm_free(arr_a);
    _mm_free(arr_b);
    _mm_free(arr_c);
}
```
其中`print_binary`是一个打印二进制的函数, 这里只打印了后8位
```c
// 打印二进制
 void print_binary(uint64_t t, int bit_len) {
	short buffer[bit_len];
	int i;
	for(i = 0; i < bit_len; i++) {
		buffer[i] = 0;
	}

	for (i = 0; i < bit_len; i++) {
		if (t == 0)
			break;
		if (t % 2 == 0) {
			buffer[i] = 0;
		} else {
			buffer[i] = 1;
		}
		t = t / 2;
	}
	for (i = bit_len - 1; i >= 0; i--) {
		printf("%hd", buffer[i]);
	}
}
```
下面是一个取反的示例
```c
void mic_not() {
    uint32_t *arr_a, *arr_c;
    int i = 0, n = 16;

    arr_a = _mm_malloc(sizeof(uint32_t) * n, 64);
    arr_c = _mm_malloc(sizeof(uint32_t) * n, 64);

    for(i = 0; i < n; i++) {
        arr_a[i] = i ;
    }

#pragma offload target(mic) in(arr_a:length(n)) out(arr_c:length(n))
    {
        __m512i m_a, m_b, m_c;
        int32_t all_one = 0xffffffff;
        // _mm512_set1_epi32 : 将向量中的16个整型都设为all_one
        m_b = _mm512_set1_epi32(all_one);
        m_a = _mm512_load_epi32(arr_a);
        m_c = _mm512_xor_epi32(m_a, m_b);
        _mm512_store_epi32(arr_c, m_c);
    }

    for(i = 0; i < n; i++) {
        printf("~ ");
        print_binary (arr_a[i], 8);
        printf( " = ");
        print_binary(arr_c[i], 8);
        printf("\n");

    }
    _mm_free(arr_a);
    _mm_free(arr_c);
}
```
下面是运行结果
```html
~ 00000000 = 11111111
~ 00000001 = 11111110
~ 00000010 = 11111101
~ 00000011 = 11111100
~ 00000100 = 11111011
~ 00000101 = 11111010
~ 00000110 = 11111001
~ 00000111 = 11111000
~ 00001000 = 11110111
~ 00001001 = 11110110
~ 00001010 = 11110101
~ 00001011 = 11110100
~ 00001100 = 11110011
~ 00001101 = 11110010
~ 00001110 = 11110001
~ 00001111 = 11110000
```

### 移位操作
移位操作分为算术移位和逻辑移位, 逻辑左移和算术左移的规则是一样的, 所以两者共用同一个左移函数, 而逻辑右移和算术右移不同, 逻辑右移是一直补0, 而算术右移要看符号位, 符号位为0则补0, 符号位为1, 则补1. 同时移位操作有两种形式, 一种给定一个常数, 向量中的每个元素都移该常数位, 一种是给定一个向量, 向量中的每个元素移给定向量中对应数值的位. 好吧下面还是看例子吧.
__左移: 给定一个常数__
```c
void mic_lshift() {
    uint32_t *arr_a, *arr_c;
    int i = 0, n = 16;

    arr_a = _mm_malloc(sizeof(uint32_t) * n, 64);
    arr_c = _mm_malloc(sizeof(uint32_t) * n, 64);

    for(i = 0; i < n; i++) {
        arr_a[i] = i ;
    }

#pragma offload target(mic) in(arr_a:length(n)) out(arr_c:length(n))
    {
        __m512i m_a, m_c;
        m_a = _mm512_load_epi32(arr_a);
        // 向量中的每个整型都左移一位 ,逻辑右移 _mm512_srli_epi32
        m_c = _mm512_slli_epi32 (m_a, 1);
        _mm512_store_epi32(arr_c, m_c);
    }

    for(i = 0; i < n; i++) {
        print_binary (arr_a[i], 8);
        printf( " \t  ");
        print_binary(arr_c[i], 8);
        printf("\n");
    }
    _mm_free(arr_a);
    _mm_free(arr_c);
}
```
__左移:给定一个向量__
```c
void mic_lshift_v() {
    uint32_t *arr_a, *arr_c;
    int i = 0, n = 16;

    arr_a = _mm_malloc(sizeof(uint32_t) * n, 64);
    arr_c = _mm_malloc(sizeof(uint32_t) * n, 64);

    for(i = 0; i < n; i++) {
        arr_a[i] = i+1 ;
    }

#pragma offload target(mic) in(arr_a:length(n)) out(arr_c:length(n))
    {
        __m512i m_a, m_b, m_c;
        // _mm512_set_epi32(int e15, int e14, int e13, int e12, int e11, int e10, int e9, int e8, int e7, int e6, int e5, int e4, int e3, int e2, int e1, int e0);
        // _mm512_set_epi32 按从高到低的顺序, 第一个参数设为向量中第16个整型的值, 最后一个参数设为第1个整型的值
        m_b = _mm512_set_epi32(1,2,3,4,1,2,3,4,1,2,3,4,1,2,3,4);
        m_a = _mm512_load_epi32(arr_a);
        //  逻辑右移 _mm512_srlv_epi32
        m_c = _mm512_sllv_epi32 (m_a, m_b);
        _mm512_store_epi32(arr_c, m_c);
    }

    for(i = 0; i < n; i++) {
        print_binary (arr_a[i], 8);
        printf( " \t  ");
        print_binary(arr_c[i], 8);
        printf("\n");

    }
    _mm_free(arr_a);
    _mm_free(arr_c);
}
```
执行结果为:
```html
00000001 	  00010000
00000010 	  00010000
00000011 	  00001100
00000100 	  00001000
00000101 	  01010000
00000110 	  00110000
00000111 	  00011100
00001000 	  00010000
00001001 	  10010000
00001010 	  01010000
00001011 	  00101100
00001100 	  00011000
00001101 	  11010000
00001110 	  01110000
00001111 	  00111100
00010000 	  00100000
```
__算术右移__
```c
void mic_arshift() {
    uint32_t *arr_a, *arr_b, *arr_c, *arr_d;
    int i = 0, n = 16;

    arr_a = _mm_malloc(sizeof(uint32_t) * n, 64);
    arr_b = _mm_malloc(sizeof(uint32_t) * n, 64);
    arr_c = _mm_malloc(sizeof(uint32_t) * n, 64);
    arr_d = _mm_malloc(sizeof(uint32_t) * n, 64);

    uint32_t high_one = 1 << 31;
    for(i = 0; i < n; i++) {
        arr_a[i] = i+1;
        arr_b[i] = high_one | (i + 1);
    }

#pragma offload target(mic) in(arr_a:length(n)) in(arr_b:length(n)) out(arr_c:length(n)) out(arr_d:length(n))
    {
        __m512i m_a,m_b, m_c, m_d;
        m_a = _mm512_load_epi32(arr_a);
        //  算术右移, 符号为0, 补0；符号位为1, 补1
        m_c = _mm512_srai_epi32 (m_a, 2);
        _mm512_store_epi32(arr_c, m_c);
        m_b = _mm512_load_epi32(arr_b);
        m_d = _mm512_srai_epi32(m_b, 2);
        _mm512_store_epi32(arr_d, m_d);
    }

    printf("符号位为0: \n");
    for(i = 0; i < n; i++) {
        print_binary (arr_a[i],32);
        printf( " \t  ");
        print_binary(arr_c[i], 32);
        printf("\n");

    }

    printf("符号位为1: \n");
    for(i = 0; i < n; i++) {
        print_binary (arr_b[i],32);
        printf( " \t  ");
        print_binary(arr_d[i], 32);
        printf("\n");
    }

    _mm_free(arr_a);
    _mm_free(arr_b);
    _mm_free(arr_c);
    _mm_free(arr_d);
}
```
执行结果为:
```
符号位为0:
00000000000000000000000000000001 	  00000000000000000000000000000000
00000000000000000000000000000010 	  00000000000000000000000000000000
00000000000000000000000000000011 	  00000000000000000000000000000000
00000000000000000000000000000100 	  00000000000000000000000000000001
00000000000000000000000000000101 	  00000000000000000000000000000001
00000000000000000000000000000110 	  00000000000000000000000000000001
00000000000000000000000000000111 	  00000000000000000000000000000001
00000000000000000000000000001000 	  00000000000000000000000000000010
00000000000000000000000000001001 	  00000000000000000000000000000010
00000000000000000000000000001010 	  00000000000000000000000000000010
00000000000000000000000000001011 	  00000000000000000000000000000010
00000000000000000000000000001100 	  00000000000000000000000000000011
00000000000000000000000000001101 	  00000000000000000000000000000011
00000000000000000000000000001110 	  00000000000000000000000000000011
00000000000000000000000000001111 	  00000000000000000000000000000011
00000000000000000000000000010000 	  00000000000000000000000000000100
符号位为1:
10000000000000000000000000000001 	  11100000000000000000000000000000
10000000000000000000000000000010 	  11100000000000000000000000000000
10000000000000000000000000000011 	  11100000000000000000000000000000
10000000000000000000000000000100 	  11100000000000000000000000000001
10000000000000000000000000000101 	  11100000000000000000000000000001
10000000000000000000000000000110 	  11100000000000000000000000000001
10000000000000000000000000000111 	  11100000000000000000000000000001
10000000000000000000000000001000 	  11100000000000000000000000000010
10000000000000000000000000001001 	  11100000000000000000000000000010
10000000000000000000000000001010 	  11100000000000000000000000000010
10000000000000000000000000001011 	  11100000000000000000000000000010
10000000000000000000000000001100 	  11100000000000000000000000000011
10000000000000000000000000001101 	  11100000000000000000000000000011
10000000000000000000000000001110 	  11100000000000000000000000000011
10000000000000000000000000001111 	  11100000000000000000000000000011
10000000000000000000000000010000 	  11100000000000000000000000000100
```
### _mm512_alignr_epi32
函数原型为:
```c
extern __m512i __cdecl _mm512_alignr_epi32(__m512i v2, __m512i v3, const int count);
```
该函数的作用就是将v2和v3拼接起来, v2在前, v3在后, 然后循环左移count个元素, 然后取最右侧的16个元素, 下面看个例子
```c
void mic_alignr() {
    uint32_t *arr_a, *arr_b, *arr_c, *arr_d;
    int i = 0, n = 16;

    arr_a = _mm_malloc(sizeof(uint32_t) * n, 64);
    arr_b = _mm_malloc(sizeof(uint32_t) * n, 64);
    arr_c = _mm_malloc(sizeof(uint32_t) * n, 64);
    arr_d = _mm_malloc(sizeof(uint32_t) * n, 64);

    for(i = 0; i < n; i++) {
        arr_a[i] = i+1;
        arr_b[i] = n + i + 1;
    }

#pragma offload target(mic) in(arr_a:length(n)) in(arr_b:length(n)) out(arr_c:length(n)) out(arr_d:length(n))
    {
        __m512i m_a,m_b, m_c, m_d;
        m_a = _mm512_load_epi32(arr_a);
        m_b = _mm512_load_epi32(arr_b);
        //  算术右移, 符号为0, 补0；符号位为1, 补1
        m_c = _mm512_alignr_epi32 (m_a, m_b, 3);
        _mm512_store_epi32(arr_c, m_c);
        m_d = _mm512_alignr_epi32(m_a, m_b, 8);
        _mm512_store_epi32(arr_d, m_d);
    }

    printf("arr_a: ");
    for(i = 0; i < n; i++) {
        printf("%2u ", arr_a[i]);
    }
    printf(" \narr_b: ");
    for(i = 0; i < n; i++) {
        printf("%2u ", arr_b[i]);
    }
    printf("\n\n");
    printf("count = 3  arr_c: ");
    for(i = 0; i < n; i++) {
        printf("%2u ", arr_c[i]);
    }
    printf("\n");

    printf("count = 8  arr_c: ");
    for(i = 0; i < n; i++) {
        printf("%2u ", arr_d[i]);
    }

    printf("\n");

    _mm_free(arr_a);
    _mm_free(arr_b);
    _mm_free(arr_c);
    _mm_free(arr_d);
}
```
执行结果为:
```html
arr_a:  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16  
arr_b: 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32

count = 3  arr_c: 20 21 22 23 24 25 26 27 28 29 30 31 32  1  2  3
count = 8  arr_c: 25 26 27 28 29 30 31 32  1  2  3  4  5  6  7  8
```
