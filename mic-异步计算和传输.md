# 异步计算和传输
<!-- toc -->
## 异步计算
当使用#pragma offload target(mic) 方式分载时, cpu会等待offload的代码块执行完再继续往下执行, 如果不希望等待offload, 我们可以使用cpu和mic异步计算的方式. 具体方法为在offload的时候添加一个信号量, 如下面的形式:
```c
char signal_var;

#pragma offload target(mic:0)signal(&signal_var)
{
    ...    
}
```
此时offload 的代码就会异步执行, 需要注意的一点是要制定mic的编号(如上面的`target(mic:0)`), 如果需要等待offload执行完后在往下执行, 可以使用`offload_wait`, 如下面的形式

```c
#pragma offload_wait target(mic:0) wait(&signal_var)
```
<!-- more -->
当代码执行到这一句时如果offload没有执行完就会处于等待状态, 直到offload执行完再往下执行. 下面是一个完整的示例, test1是异步执行, test2是同步执行.
```c
#include <stdio.h>
#include <offload.h>

void test1() {
    char signal_var;
    //需要指定mic卡的编号
#pragma offload target(mic:0)signal(&signal_var)
    {
        long long i;
        long long t;
        for(i = 0; i < 1000000000; i++) {
            t += i;
            t += i * 2;
            t += i * 3;
            t +=i %2;
            t += i %3;
        }
        printf("t is %lld\n", t);
    }

    int j = 0;
    for(j = 0; j < 100000; j++) {}
    printf("j is %d\n", j);

#pragma offload_wait target(mic:0) wait(&signal_var)

    printf("after wait\n");
}

void test2() {

#pragma offload target(mic:0)
    {
        long long i;
        long long t;
        for(i = 0; i < 1000000000; i++) {
            t += i;
            t += i * 2;
            t += i * 3;
            t +=i %2;
            t += i %3;
        }
        printf("t is %lld\n", t);
    }

    int j = 0;
    for(j = 0; j < 100000; j++) {}
    printf("j is %d\n", j);
    printf("after wait\n");
}

int main() {
    test1();
    //test2();
}

```

## 异步传输
如果数据量很大, 那么cpu和mic之间的数据传输也要花费一些时间, 如果不希望等待数据传输, 那么可以使用`offload_transfer`进行异步数据传输, 如下面的方式
```c
#pragma offload_transfer target(mic:0) signal(f1) \
    in (f1:length(n) alloc_if(1) free_if(0))
```
如果后面的offload需要使用本次offload上传的数据, 那么可以使用wait来等待数据传输完毕再执行
```c
#pragma offload target(mic:0) wait(f1)
```
下面是一个完整的示例:
```c
#include <stdio.h>
#include <stdlib.h>
#define __ONMIC__ __attribute__((target(mic)))

__ONMIC__ void add_inputs(int n, float *f1, float *f2){
    int i;
    for( i =0; i < n; i++) {
        f2[i] += f1[i];
    }
}

void display_vals( int id, int n,  float *f2) {
    printf("\nResults after Offload #%d:\n",id);

    int i;
    for ( i = 0; i < n; i++) {
        printf("f2[%d] is %f\n", i, f2[i] );
    }
    printf("====================\n");
}
void test() {
    float *f1 , *f2;
    int n = 10000;
    int i, j;
    f1 = (float*) malloc(sizeof(float) * n);
    f2 = (float*)malloc(sizeof(float) * n);

    for(i = 0; i < n; i++) {
        f1[i] = i+1;
        f2[i] = 0.0;
    }
    // 这里只上传数据
#pragma offload_transfer target(mic:0) signal(f1) \
    in (f1:length(n) alloc_if(1) free_if(0))\
    in (f2:length(n) alloc_if(1) free_if(0))

    // wait(f1)等待上面的数据传输完毕, 再执行该操作
#pragma offload target(mic:0) wait(f1) signal(f2) \
    in(n) \
    nocopy(f1:alloc_if (0) free_if(1))\
    out(f2:length(n) alloc_if(0) free_if(1))
    add_inputs(n, f1, f2);

    // 等该f2执行完
#pragma offload_wait target(mic:0) wait(f2)

    // 如果不加wait, 就会全部打印出0
    display_vals(1, 10, f2);

    // 多个数据异步上传
#pragma offload_transfer target(mic:0) signal(f1) \
    in(f1:length(n) alloc_if(1) free_if(0))

#pragma offload_transfer target(mic:0) signal(f2) \
    in(f2:length(n) alloc_if(1) free_if(0))

    // 同时等待两个信号量
#pragma offload target(mic:0) wait(f1, f2) \
    in (n) \
    nocopy (f1:alloc_if(0) free_if(1)) \
    out (f2:length(n) alloc_if(0) free_if(1))
    add_inputs(n, f1, f2);

    display_vals(2, 10, f2);

    // 异步传输和同步传输结合
#pragma offload_transfer target(mic:0) signal(f2)\
    in(f2:length(n) alloc_if(1) free_if(0))

#pragma offload target(mic:0) wait(f2) \
    in(n) \
    in(f1:length(n) alloc_if(1) free_if(0))\
    nocopy(f2)
    add_inputs(n ,f1, f2);

#pragma offload_transfer target(mic:0) signal(f2) \
    out(f2:length(n) alloc_if(0) free_if(1))

#pragma offload_wait target(mic:0) wait(f2)

    display_vals(3, 10, f2);

    free(f1);
    free(f2);
}

int main() {
    test();
}

```
