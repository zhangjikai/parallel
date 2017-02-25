# Offload 其他函数
<!-- toc -->
## into
使用into可以将一个变量的值上传到另外一个变量中, 比如`in (a into(b))`, 表示将CPU上变量a的值赋给MIC上的变量b, 也可以`out(b into(c))` 将MIC上变量b的值传回给CPU上的变量c. 需要注意的地方是into 只能用于in或者out中, 不能用于inout或者nocopy中. 下面是使用示例:
<!-- more -->
```c
#include <stdio.h>

void init_array(int* arr, int n, int start_num){
    int i;
    for(i = 0; i < n; i++) {
        arr[i] = start_num + i;
    }
}

void use_into() {
    int n = 3, i;
    int p[n], p1[n];

    init_array(p, n, 0);
    init_array(p1, n, n);

    for(i = 0; i < n; i++) {
        printf("before offload:  p[%d] is %d\n", i, p[i]);
    }
    for(i = 0; i < n; i++) {
        printf("before offload: p1[%d] is %d\n", i, p1[i]);
    }

    printf("==============================\n");
    //into 将一个变量的值上传到另外一个变量中,如下在mic上p没有值,只有p1有值, 调用out之后原先p1的值会改变
#pragma offload target(mic) in(p[0:n] : into(p1[0:n])) out(p1)
    {
        for(i = 0; i < n; i++) {
            printf("On Mic:  p[%d] is %d\n", i, p[i]);
        }
        for(i = 0; i < n; i++) {
            printf("On Mic: p1[%d] is %d\n", i, p1[i]);
        }
    }

    for(i = 0; i < n; i++) {
        printf("after offload:  p[%d] is %d\n", i, p[i]);
    }
    for(i = 0; i < n; i++) {
        printf("after offload: p1[%d] is %d\n", i, p1[i]);
    }

    printf("==============================\n");
}

void use_into2() {
    int n = 4, i;
    int p[n], p1[n+1], p2[n-1];

    init_array(p, n, 0);
    init_array(p1, n+1, n);
    init_array(p2, n-1, 2*n+1);

    for(i = 0; i < n; i++) {
        printf("before offload:	 p[%d] is %d\n", i, p[i]);
    }
    for(i = 0; i < n+1; i++) {
        printf("before offload: p1[%d] is %d\n", i, p1[i]);
    }
    for(i = 0; i < n-1; i++) {
        printf("before offload: p2[%d] is %d\n", i, p2[i]);
    }
    printf("==============================\n");
    // 当数组长度不一样时, 当length(p) < length(p1)时, p1数组多余的部分会补0
    // 当length(p) > length(p2)时, in的时候需要注意p的长度不可大于p2的长度
#pragma offload target(mic) in(p[0:n]:into(p1[0:n+1])) in(p[0:n-1]:into(p2[0:n-1])) out(p1) out(p2)
    {
        for(i = 0; i < n; i++) {
            printf("on mic:  p[%d] is %d\n", i, p[i]);
        }
        for(i = 0; i < n+1; i++) {
            printf("on mic: p1[%d] is %d\n", i, p1[i]);
        }
        for(i = 0; i < n-1; i++) {
            printf("on mic: p2[%d] is %d\n", i, p2[i]);
        }
    }

    for(i = 0; i < n; i++) {
        printf("after offload:  p[%d] is %d\n", i, p[i]);
    }
    for(i = 0; i < n+1; i++) {
        printf("after offload: p1[%d] is %d\n", i, p1[i]);
    }
    for(i = 0; i < n-1; i++) {
        printf("after offload: p2[%d] is %d\n", i, p2[i]);
    }
    printf("==============================\n");
}

// 将一维数组放到二维数组里以及二维数组放到一维数组,
// 文档中说不可以, 但是这里确实可以使用
void use_into3() {
    int n = 10, i;
    int p[n * n];
    int a[n][n];

    init_array(p, n * n, 0);
#pragma offload target(mic)  in(p:into(a)) out(a:into(p))
    {
        for(i = 0; i < n; i++) {
            printf("on mic: a[%d][0] is %d\n", i, a[i][0]);

        }

        // 相当于p[0]
        a[0][0] = 1000;
        // 相当于p[10]
        a[1][0] = 1000;
    }

    printf("p[0] is %d and p[10] is %d\n", p[0], p[10]);
    printf("==============================\n");
}

int main() {
    use_into();
    //use_into2();
    //use_into3();
}

```

## alloc_if 和 free_if
对于指针变量来说, 每次执行offload都会为其分配新的内存, 当offload执行完之后, 就会将该内存释放掉. 为了能够重用前面offload所开辟的空间, mic提供了alloc_if和free_if来显示指定是否为offload的指针变量(非指针变量使用alloc_if和free_if会报错)分配新的内存以及执行完offload后是否释放该内存. 下面是具体含义:
* __alloc_if(1)__ - offload时为指针分配新的内存
* __alloc_if(0)__ - offload时不开辟新的内存, 而是使用前面保留的内存
* __free_if(1)__  - offload执行完成后, 释放掉为该指针分配的内存
* __free_if(0)__  - offload执行完成后, 不释放指针对应的内存

默认值是alloc_if(1) 和 free_if(1), 为了使程序更加清晰, 我们预定义几个宏
```c
#define ALLOC alloc_if(1)
#define FREE free_if(1)
#define RETAIN free_if(0)
#define REUSE alloc_if(0)
```
下面是具体的示例代码:
```c
#include <stdio.h>
#include <stdlib.h>

#define ALLOC alloc_if(1)
#define FREE free_if(1)
#define RETAIN free_if(0)
#define REUSE alloc_if(0)

void init_array(int* arr, int n, int start_num){
    int i;
    for(i = 0; i < n; i++) {
        arr[i] = start_num + i;
    }
}

// 当mic上没有未释放的内存时, 使用alloc_if(0)会报错
void reuse_before_alloc() {
    int n = 10;
    int *p =(int*) calloc(n, sizeof(int));
    int i;
    init_array(p, n, 0);
    //当然这是错的offload error: cannot find data associated with pointer variable 0x15e2c60
    //因为没有已有的内存
#pragma offload target(mic) in(p:length(10) REUSE)
    {
        for(i = 0; i < n; i++) {
            printf("the p[%d] id %d\n", i, p[i]);
        }
    }
    free(p);
}

//这里保存内存, 在下面执行reuse, reuse2 之前都应该先执行该函数在MIC上保存内存.
void retain() {

    int n = 10;
    int *p =(int*) calloc(n, sizeof(int));
    int i;
    init_array(p, n, 0);
#pragma offload target(mic) in(p:length(n) RETAIN)
    {
        for(i = 0; i < n; i++) {
            printf("retain: the p[%d] id %d\n", i, p[i]);
        }
    }
    free(p);
}

//这里使用上面保存的内存空间
void reuse() {
    int n = 10;
    int *p =(int*) calloc(n, sizeof(int));
    int i;
    init_array(p, n, 0);
    //如果不加retain会默认释放掉该内存
#pragma offload target(mic) in(p:length(n) REUSE)
    {
        for(i = 0; i < n; i++) {
            printf("reuse: the p[%d] id %d\n", i, p[i]);
        }
    }
    free(p);
}

// 重用的内存不可以大于MIC上已保存的内存, 小于是可以的
void reuse2() {
    // 如果n=11就会报错
    int n = 9;
    int *p =(int*) calloc(n, sizeof(int));
    int i;
    init_array(p, n, 0);
#pragma offload target(mic) in(p:length(n) REUSE)
    {
        for(i = 0; i < n; i++) {
            printf("reuse: the p[%d] is %d\n", i, p[i]);
        }
    }
    free(p);
}


int main(){

    //	reuse_before_alloc();

    retain();
    reuse();

    //	retain();
    //	reuse2();

    return 0;
}

```
还有一个问题就是重用内存的时候好像是不需要两个变量名相同, 看下面的代码
```c
void retain() {

    int n = 10;
    int *p =(int*) calloc(n, sizeof(int));
    int i;
    init_array(p, n, 0);
#pragma offload target(mic) in(p:length(n) RETAIN)
    {
        for(i = 0; i < n; i++) {
            printf("retain: the p[%d] id %d\n", i, p[i]);
        }
    }
    free(p);
}

void reuse() {
    int n = 10;
    int *p2 =(int*) calloc(n, sizeof(int));
    int i;
    init_array(p2, n, 0);
#pragma offload target(mic) in(p2:length(n) REUSE)
    {
        for(i = 0; i < n; i++) {
            printf("reuse: the p2[%d] is %d\n", i, p2[i]);
        }
    }
    free(p2);

}

```
首先执行retain, 然后在执行reuse, 程序仍然可以正常运行.

## Applying the target Attribute to Multiple Declarations
当有多个变量或者函数需要在MIC上使用时, 我们可以采用一种较为方便的声明方式为这些变量和函数加上 target(mic) 的属性, 下面是声明方式:
```c
#pragma offload_attribute(push, target(mic))
...
#pragma offload_attribute(pop)
```
在两个#pragma之间声明的变量和函数都可以在mic上运行, 如果要声明共享虚拟内存模式下使用的共享变量和函数, 可以采用下面的形式
```c
#pragma offload_attribute(push, _Cilk_shared)
...
#pragma offload_attribute(pop)
```
下面是一个示例:
```c
#pragma offload_attribute(push, target(mic))
#include <stdio.h>
#include <stdlib.h>

void test1();
void test2();
#pragma offload_attribute(pop)

int main() {
#pragma offload target(mic)
    test1();

#pragma offload target(mic)
    test2();
}

void test1() {
    printf("this is test1\n");
}

void test2() {
    printf("this is test2\n");
}

```
