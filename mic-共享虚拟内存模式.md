# 共享虚拟内存
<!-- toc -->

## 前言
使用 #pragma offload target(mic) 方式将程序分载到MIC上计算是比较常用的方式, 但是这种方式只支持一维指针, 如果有较为复杂的数据结构, 比如二维指针, 树, 链表等结构则需要将这些数据结构转换为一维结构(如果可以), 否则不能将数据传到MIC上去. 为了满足复杂的数据结构, mic提供了共享虚拟内存的方式, 即将mic的内存和cpu的内存看做共享同一块虚拟内存, 在共享内存中的数据被cpu和mic共享, 不需要使用offload将数据在cpu和mic之间相互传递.
<!-- more -->
## 声明共享变量和函数
我们可以使用`_Cilk_shared`来声明mic和cpu共享的变量和函数, 使用`_Cilk_offload`在mic端运行共享函数.
```c
_Cilk_shared int i;

_Cilk_shared void a();
```
共享变量的虚拟内存地址在cpu和mic上是相同的, 并且它们的值会在cpu和mic之间同步. 下面是一个示例:

```c
#include <stdio.h>
#include <stdlib.h>

// 声明CPU和MIC共享的变量
_Cilk_shared int x = 1;

// 声明CPU和MIC共享的函数
_Cilk_shared void run_onmic() {
    x = 3;
    printf("mic: the value of x is %d and the address of mic is %p\n", x, &x);

    // 确认是否在mic上执行
#ifdef __MIC__
    printf("this is onmic\n");
#endif
}

void run_oncpu() {
    printf("cpu: the value of x is %d and the address of mic is %p\n", x, &x);
}

int main() {
    // 使用_Cilk_offload 代替#pragma offload target(mic)
    _Cilk_offload run_onmic();
    run_oncpu();
}

```
## 指针内存管理
首先说下共享指针的声明方式:
```c
int *_Cilk_shared share_pointer;
```
上面是声明一个共享指针, 注意`*`号在`_Cilk_shared`的前面, 下面的两种方式都不是共享指针正确的声明方式
```c
int _Cilk_shared *share_pointer;

_Cilk_shared int *share_pointer;
```
共享内配的分配和释放应该使用下面的函数
```c
void *_Offload_shared_malloc(size_t size);
void *_Offload_shared_aligned_malloc(size_t size, size_t alignment);

_Offload_shared_free(void *p);
_Offload_shared_aligned_free(void *p);
```
其中`_Offload_shared_aligned_malloc` 和 `_Offload_shared_aligned_free` 用于处理需要内存对齐时的情况. 不过好像在共享函数中可以使用malloc为共享变量分配内存, 但是不清楚是否会有什么副作用. 还要注意的一点是`_Offload_shared_malloc`和`free` , `malloc`和`_Offload_shared_free` 不能混用, 否则可能出现意想不到的结果, 下面是一个示例代码:
```c
#include <stdio.h>
#include <stdlib.h>

// int _Cilk_shared *p 是本地指针, 可以指向共享数据, 如果直接p = _Offload_share_malloc() 会报warning
// 而使用下面的方式定义则没有问题
// typedef int *fp;
// _Cilk_shared fp p;
// p = (fp)_Offload_shared_malloc(sizeof(int) * n);
// _Offload_shared_free(p);
int *_Cilk_shared share_pointer;

_Cilk_shared int n = 8;

// 在共享函数内, 使用malloc和free为共享变量分配和释放内存
_Cilk_shared void cilk_malloc() {

    int i;
    share_pointer = (int *)malloc(sizeof(int) * n);
    for(i = 0; i < n; i++) {
        share_pointer[i] = i;
    }

    for(i = 0; i < n; i++) {
        printf("cilk_malloc: share_pointer[%d] is %d\n", i, share_pointer[i]);
    }
    free(share_pointer);
}

// 在mic上执行下面函数会报错
// CARD--ERROR:1 thread:3 myoArenaFree: It is not supported to free shared memory from the MIC side!
_Cilk_shared void cilk_sharedfree() {
    int i;
    share_pointer = (int *)_Offload_shared_malloc(sizeof(int) * n);
    for(i = 0; i < n; i++) {
        share_pointer[i] = i;
    }

    for(i = 0; i < n; i++) {
        printf("cilk_sharedfree: share_pointer[%d] is %d\n", i, share_pointer[i]);
    }
    _Offload_shared_free(share_pointer);
}


_Cilk_shared void cilk_pointer() {
    int i;
    for(i = 0; i < n; i++) {
        share_pointer[i] = i;
    }

    for(i = 0; i < n; i++) {
        printf("cilk_pointer: share_pointer[%d] is %d\n", i, share_pointer[i]);
    }
}

int main() {

    //_Cilk_offload cilk_malloc();

    //_Cilk_offload cilk_sharedfree();

    // 下面三条语句执行时会错误
    //share_pointer =(int *) malloc(sizeof(int) * n);
    //_Cilk_offload cilk_pointer();
    //free(share_pointer);

    // 下面三条语句可以正常执行
    share_pointer = (int *) _Offload_shared_malloc(sizeof(int) * n);
    _Cilk_offload cilk_pointer();
    _Offload_shared_free(share_pointer);

    return 0;
}
```
当在mic上执行cilk_share_free时会报错误, 原因是只能在cpu端调用`_Offload_shared_free`函数释放内存.
## 二维指针示例
下面是一个使用共享二维指针的一个示例
```c
#include <stdio.h>

int **_Cilk_shared p;
_Cilk_shared int n = 3, m = 3;

void init_p() {
    int index = 0, i, j;
    for(i = 0; i < n; i++) {
        for( j = 0; j < m; j++) {
            p[i][j] = index++;
        }
    }
}

_Cilk_shared void print_p() {
    int i, j;
    for(i = 0; i < n; i++) {
        for(j = 0; j < n; j++) {
            printf("print_p: p[%d][%d] is %d\n", i, j, p[i][j]);
        }
    }
}

int main() {
    int i;
    p = (int **) _Offload_shared_malloc(sizeof(int *) * n);
    for( i = 0; i < n ;i++) {
        p[i] =(int *) _Offload_shared_malloc(sizeof(int) * m);
    }

    init_p();
    _Cilk_offload print_p();
    for(i = 0; i < n; i++) {
        _Offload_shared_free(p[i]);
    }

    _Offload_shared_free(p);
}

```
