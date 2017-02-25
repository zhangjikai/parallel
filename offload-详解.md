# in / out / inout 详细用法
下面的代码主要使用in作为测试, out和inout的用法应该是类似的， 下面主要以代码为主， 并且附带执行结果。
<!-- toc -->

## 静态一维数组
```c
#include <stdio.h>
#include <stdlib.h>

void offload_one_dim_array(int n) {
    int arr[n];
    int arr2[n];
    int arr3[n];
    int i;

    for(i = 0; i < n; i++) {
        arr[i] = i;
        arr2[i] = n + i;
        arr3[i] = 2 * n + i;
    }

    //上传arr的全部元素,上传arr2的前0-4共5(长度为5)个元素,上传arr3的从索引2开始的5个元素(即索引2-6)到mic上
    #pragma offload target(mic) in(arr) in(arr2:length(5)) in(arr3[1:5])
    {
        for(i = 0; i < n; i++) {
            printf(" arr[%d] is %d\n", i, arr[i]);
        }

        printf("==========================\n");

        for(i = 0; i < n; i++) {
            printf("arr2[%d] is %d\n", i, arr2[i]);
        }

        printf("==========================\n");

        for(i = 0; i < n; i++) {
            printf("arr3[%d] is %d\n", i, arr3[i]);
        }
    }
}

int main() {
    offload_one_dim_array(10);
    return 0;
}
```
输出结果为:
```bash
 arr[0] is 0
 arr[1] is 1
 arr[2] is 2
 arr[3] is 3
 arr[4] is 4
 arr[5] is 5
 arr[6] is 6
 arr[7] is 7
 arr[8] is 8
 arr[9] is 9
==========================
arr2[0] is 10
arr2[1] is 11
arr2[2] is 12
arr2[3] is 13
arr2[4] is 14
arr2[5] is 0
arr2[6] is 0
arr2[7] is 0
arr2[8] is 0
arr2[9] is 0
==========================
arr3[0] is 0
arr3[1] is 0
arr3[2] is 22
arr3[3] is 23
arr3[4] is 24
arr3[5] is 25
arr3[6] is 26
arr3[7] is 0
arr3[8] is 0
arr3[9] is 0
```
## 静态二维数组
```c
#include <stdio.h>
#include <stdlib.h>

void offload_two_dim_array(int n) {
    int arr[n][n];
    int arr2[n][n];
    int arr3[n][n];
    int arr4[n][n];
    int i, j, index = 0;
    for(i = 0; i < n; i++) {
        for(j = 0; j < n; j++) {
            arr[i][j] = index;
            arr2[i][j] = n * n + index;
            arr3[i][j] = 2 * n * n + index;
            arr4[i][j] = 3 * n * n + index;
            index++;
        }
    }

    //上传arr的全部值,上传arr2的前5个值(整体看为长度为n*n的一维数组,取前5个值),上传arr3中[0-1][0-(n-1)]的值,
    //不加后面的y的维度,默认y的是1-(n-1), 上传arr4中[0-1][0-1]的值
    #pragma offload target(mic) in(arr) in(arr2:length(5)) in(arr3[0:2]) in(arr4[0:2][0:2])
    {
        for(i = 0; i < n; i++) {
            for(j = 0; j < n; j++) {
                printf(" arr[%d][%d] is %d\n", i, j, arr[i][j]);
            }
        }

        printf("==========================\n");

        for(i = 0; i < n; i++) {
            for(j = 0; j < n; j++) {
                printf("arr2[%d][%d] is %d\n", i, j, arr2[i][j]);
            }
        }

        printf("==========================\n");

        for(i = 0; i < n; i++) {
            for(j = 0; j < n; j++) {
                printf("arr3[%d][%d] is %d\n", i, j,  arr3[i][j]);
            }
        }

        printf("==========================\n");

        for(i = 0; i < n; i++) {
            for(j = 0; j < n; j++) {
                printf("arr4[%d][%d] is %d\n", i, j, arr4[i][j]);
            }
        }
    }
}

int main() {
    offload_two_dim_array(3);
    return 0;
}
```
下面是输出结果
```bash
 arr[0][0] is 0
 arr[0][1] is 1
 arr[0][2] is 2
 arr[1][0] is 3
 arr[1][1] is 4
 arr[1][2] is 5
 arr[2][0] is 6
 arr[2][1] is 7
 arr[2][2] is 8
==========================
arr2[0][0] is 9
arr2[0][1] is 10
arr2[0][2] is 11
arr2[1][0] is 12
arr2[1][1] is 13
arr2[1][2] is 0
arr2[2][0] is 0
arr2[2][1] is 0
arr2[2][2] is 0
==========================
arr3[0][0] is 18
arr3[0][1] is 19
arr3[0][2] is 20
arr3[1][0] is 21
arr3[1][1] is 22
arr3[1][2] is 23
arr3[2][0] is 0
arr3[2][1] is 0
arr3[2][2] is 0
==========================
arr4[0][0] is 27
arr4[0][1] is 28
arr4[0][2] is 0
arr4[1][0] is 30
arr4[1][1] is 31
arr4[1][2] is 0
arr4[2][0] is 0
arr4[2][1] is 0
arr4[2][2] is 0
```
## 一个小问题
当数组(非指针)被offload一次之后会在mic上保存,并没有立即释放,在同一个作用域下,再次offload时,
如果值改变会更改为新值,如果没有offload某些位置的值,这些位置会使用上一次的旧值  
下面是局部变量测试
```c
#include <stdio.h>
#include <stdlib.h>

void offload_array_test(int n) {
    int arr[n];
    int i;
    for(i = 0; i < n; i++) {
        arr[i] = i;
    }

    #pragma offload target(mic) in(arr)
    {
        for(i = 0; i < n; i++) {
            printf("arr[%d] in first offload is %d\n", i,  arr[i]);
        }
        // 这里修改了并没有传回到CPU上, 但是会保存在MIC上
        arr[9] = 1111;
        printf("==========================\n");
    }

    arr[1] = 1000;
    arr[8] = 2000;

    //这次的offload只上传了0-2共3个值,mic上arr[1]的值会更改为1000,arr[3-(n-1)]的值会使用MIC上保存的值, 注意arr[9]的值
    #pragma offload target(mic) in(arr:length(3))
    {
        for(i = 0; i < n; i++) {
            printf("arr[%d] in second offload is %d\n",i, arr[i]);
        }
    }

    for(i = 0; i < n; i++) {
        printf("arr[%d] without offload is %d\n",i, arr[i]);
    }
    printf("==========================\n");
}

int main() {
    offload_array_test(10);
    return 0;
}
```
输出结果为:
```c
arr[0] without offload is 0
arr[1] without offload is 1000
arr[2] without offload is 2
arr[3] without offload is 3
arr[4] without offload is 4
arr[5] without offload is 5
arr[6] without offload is 6
arr[7] without offload is 7
arr[8] without offload is 2000
arr[9] without offload is 9
==========================
arr[0] in first offload is 0
arr[1] in first offload is 1
arr[2] in first offload is 2
arr[3] in first offload is 3
arr[4] in first offload is 4
arr[5] in first offload is 5
arr[6] in first offload is 6
arr[7] in first offload is 7
arr[8] in first offload is 8
arr[9] in first offload is 9
==========================
arr[0] in second offload is 0
arr[1] in second offload is 1000
arr[2] in second offload is 2
arr[3] in second offload is 3
arr[4] in second offload is 4
arr[5] in second offload is 5
arr[6] in second offload is 6
arr[7] in second offload is 7
arr[8] in second offload is 8
arr[9] in second offload is 1111
```
下面是全局变量测试:
```c
#include <stdio.h>
#include <stdlib.h>

#define __ONMIC__ __attribute__((target(mic)))

__ONMIC__ int gArr[10];

void test1() {

    int i;

    for(i = 0; i < 10; i++) {
        gArr[i] = i;
    }
    #pragma offload target(mic)
    {
        for(i = 0; i < 10; i++) {
            printf("gArr[%d] in test1 is %d\n", i, gArr[i]);
        }
        printf("==========================\n");
    }
}
void test2() {
    gArr[0] = 10;
    gArr[5] = 10;
    int i;
    #pragma offload target(mic) in(gArr[0:2])
    {
        for(i = 0; i < 10; i++) {
            printf("gArr[%d] in test2 is %d\n", i, gArr[i]);
        }
    }
}

int main() {
    test1();
    test2();
    return 0;
}
```
下面是测试结果:
```bash
gArr[0] in test1 is 0
gArr[1] in test1 is 1
gArr[2] in test1 is 2
gArr[3] in test1 is 3
gArr[4] in test1 is 4
gArr[5] in test1 is 5
gArr[6] in test1 is 6
gArr[7] in test1 is 7
gArr[8] in test1 is 8
gArr[9] in test1 is 9
==========================
gArr[0] in test2 is 10
gArr[1] in test2 is 1
gArr[2] in test2 is 2
gArr[3] in test2 is 3
gArr[4] in test2 is 4
gArr[5] in test2 is 5
gArr[6] in test2 is 6
gArr[7] in test2 is 7
gArr[8] in test2 is 8
gArr[9] in test2 is 9
```
## 一维动态数组
```c
#include <stdio.h>
#include <stdlib.h>

void offload_point() {
    int n = 10;
    int *arr =(int*) calloc(n, sizeof(int));
    int *arr2 = (int*) calloc(n, sizeof(int));
    int *arr3 = (int*) calloc(n, sizeof(int));
    int i;

    for(i = 0; i < n; i++) {
        arr[i] = i;
        arr2[i] = n + i;
        arr3[i] = n * 2 + i;
    }

    //需要注意:上传指针定义的数组时 1:要指定length或者[start:length]属性 2:要显示用in
    #pragma offload target(mic) in(arr:length(n)) in (arr2[2:3]) in (arr3:length(3))
    {
        for(i = 0; i < n; i++) {
            printf(" arr[%d] is  %d\n",i, arr[i]);
        }

        printf("==========================\n");

        for(i = 0; i < n; i++) {
            printf("arr2[%d] is %d \n",i, arr2[i]);
        }

        printf("==========================\n");

        for(i = 0; i < n; i++) {
            printf("arr3[%d] is %d \n", i, arr3[i]);
        }
    }

    free(arr);
    free(arr2);
    free(arr3);
}

int main() {
    offload_point();
    return 0;
}
```
程序输出如下:
```bash
 arr[0] is  0
 arr[1] is  1
 arr[2] is  2
 arr[3] is  3
 arr[4] is  4
 arr[5] is  5
 arr[6] is  6
 arr[7] is  7
 arr[8] is  8
 arr[9] is  9
==========================
arr2[0] is 0
arr2[1] is 0
arr2[2] is 12
arr2[3] is 13
arr2[4] is 14
arr2[5] is 0
arr2[6] is 0
arr2[7] is 0
arr2[8] is 0
arr2[9] is 0
==========================
arr3[0] is 20
arr3[1] is 21
arr3[2] is 22
arr3[3] is 0
arr3[4] is 0
arr3[5] is 0
arr3[6] is 0
arr3[7] is 0
arr3[8] is 0
arr3[9] is 0
```
## 使用指针实现的二维数组
首先用typedef定义一个一维静态数组的类型, 然后为该类型声明一个动态数组
```c
#include <stdio.h>
#include <stdlib.h>

typedef int ARRAY[5];

//下面相当于上传了一个二维数组
void offload_point2() {
    int n = 3;
    ARRAY *arr = (ARRAY*)calloc(n, sizeof(ARRAY));
    ARRAY *arr2 = (ARRAY*)calloc(n, sizeof(ARRAY));
    int i, j, index = 0;
    for(i = 0; i < n; i++) {
        for(j = 0; j < 5; j++) {
            arr[i][j] = index;
            arr2[i][j] = n *n + index;
            index++;
        }
    }

    #pragma offload target(mic) in(arr:length(n))  in (arr2[0:2][0:2])
    {
        for(i = 0; i < n; i++) {
            for(j = 0; j < 5; j++) {
                printf(" arr[%d][%d] is %d \n", i, j , arr[i][j]);
            }
        }

        printf("==========================\n");

        for(i = 0; i < n; i++) {
            for(j = 0; j < 5; j++) {
                printf("arr2[%d][%d] is %d \n", i, j , arr2[i][j]);
            }
        }
    }

    free(arr);
    free(arr2);
}

int main() {
    offload_point2();
    return 0;
}
```
输出结果为:
```bash
 arr[0][0] is 0
 arr[0][1] is 1
 arr[0][2] is 2
 arr[0][3] is 3
 arr[0][4] is 4
 arr[1][0] is 5
 arr[1][1] is 6
 arr[1][2] is 7
 arr[1][3] is 8
 arr[1][4] is 9
 arr[2][0] is 10
 arr[2][1] is 11
 arr[2][2] is 12
 arr[2][3] is 13
 arr[2][4] is 14
==========================
arr2[0][0] is 9
arr2[0][1] is 10
arr2[0][2] is 0
arr2[0][3] is 0
arr2[0][4] is 0
arr2[1][0] is 14
arr2[1][1] is 15
arr2[1][2] is 0
arr2[1][3] is 0
arr2[1][4] is 0
arr2[2][0] is 0
arr2[2][1] is 0
arr2[2][2] is 0
arr2[2][3] is 0
arr2[2][4] is 0
```
## 包含指针的struct
```c
#include <stdio.h>
#include <stdlib.h>

struct my_struct {
    int y;
    int *a;
};

void offload_struct() {
    struct my_struct m;
    m.y = 10;
    m.a =(int*) calloc(10, sizeof(int));

    int i;
    for(i=0; i < 10; i++) {
        m.a[i] = i;
    }

    //struct中有指针变量时要单独传指针变量
    #pragma offload target(mic) in(m) in(m.a:length(10))
    {
        printf("offload_struct: the struct.y is %d\n", m.y);
        printf("offload_struct: the struct.a is %d\n", m.a[1]);
    }
    free(m.a);
}

int main() {
    offload_struct();
    return 0;
}
```
## 注意事项
使用offload不能上传指针数组, 即一个数组中的每个元素是一个指针, 或者元素中包含一个指针， 比如下面的形式
```c
int **p


struct mystruct {
    int *i;
};

struct mystruct *m;
```
