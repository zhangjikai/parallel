# 流水线模型
<!-- toc -->
## 前言
Pthreads 有几种工作模型，例如 Boss/Workder Model、Pileline Model(Assembly Line)、Background Task Model、Interface/Implementation Model，详细介绍可以参考 [pthread Tutorial](http://homes.di.unimi.it/~boccignone/GiuseppeBoccignone_webpage/MatDidatSOD2009_files/pthread-Tutorial.pdf)，这里给出一个流水线模型(Pipeline Model)的简单示例。在该示例中，主线程开启了两个子线程，一个子线程用来读取文件，一个子线程用于将结果写入文件，而主线程自身用来计算。
<!-- more -->
## 模型说明
很多时候，一个程序可以分为几个阶段，比如说读取数据、计算、将结果写入文件，当然我们可以使用每个线程依次执行这些操作，但是一个更好的选择是一个线程处理一个阶段，因为对于文件操作来说，硬盘的读写速率是一定的(IO很多时候会成为性能的瓶颈)，即使多个线程读取文件，其读写速率也不会变快(IO操作无法使用线程并行)。所以我们可以用一个线程来处理IO，另外的线程全部用于计算上，如果计算量较大，IO的耗时是可以掩盖过去的。比如读取一个 2G 的文件，然后进行计算。使用流水线模型，我们可以这样做，用一个线程专门读取文件，我们将其成为IO线程。IO线程一次读取 50M 数据，之后交给计算线程来处理这些数据，在计算线程处理数据的同时，IO线程再去读文件，假设处理 50M 数据的时间大于读取50M数据的时间， 当计算线程处理完上一份数据之后，要处理的下一份数据读取完毕，那么计算线程又可以紧接着处理这部分数据，这样循环操作，除了第一次读取数据的时候计算线程处于空闲状态，其余读取的时候计算线程都在进行计算，这样就掩盖掉了IO的时间

## 实现
### 执行流程
主线程在程序开始时创建两个子线程，一个用于读，一个用于写，读线程每次只读取一部分文件内容，写线程将这部分数据处理完之后的结果写入文件。创建完线程之后，主线程和写线程就处于等待状态，而读线程就开始读取文件，当读线程读取完第一部分数据之后，读线程进入阻塞状态，主线程开始计算，主线程计算完毕后，写线程开始写入计算结果，同时读线程开始下一部分数据的读取。按照这个流程循环取算存，直到程序结束。

### 线程等待和唤醒
在执行中，3个线程都会进行等待操作，并且处理完自己的任务之后，还要再次进入等待状态。这里使用条件变量来控制线程的挂起和唤醒，使用while循环控制线程的状态的多次切换。下面是示例代码
```c
while(1) {
    pthread_mutex_lock(&read_lock);
    while(read_count == 0 ) {
        pthread_cond_wait(&read_cond, &read_lock);
    }
    read_count--;
    pthread_mutex_unlock(&read_lock);
}
```
上面的代码中，while循环会一直执行，所以我们还要加一个是否可以跳出 while 循环的判断，以便在任务结束后可以终止线程, 如下面的代码：
```c
while(1) {
    pthread_mutex_lock(&read_lock);
    while(read_count == 0 && !read_shutdown ) {
        pthread_cond_wait(&read_cond, &read_lock);
    }
    if(read_shutdown) {
        break;
    }

    read_flag =  1 - read_flag;      
    pthread_mutex_unlock(&read_lock);
}
```
我们看到在判断线程是否挂起的 while 循环中也加入了`!read_shutdown`的判断，即如果马上就要跳出while循环，标明线程已经执行完了它的任务，则无需再进行挂起操作。唤醒该线程的代码如下所示：
```c
pthread_mutex_lock(&read_lock);
if(loop_index == loop_nums - 1) {
    read_shutdown = 1;
}
read_count = 1;
pthread_cond_signal(&read_cond);
pthread_mutex_unlock(&read_lock);
```
下面分析一下条件变量，首先读线程和写线程都要对应一个条件变量，暂称为 `read_cond` 和 `write_cond`, 主线程用`read_cond`来告诉读线程自己已经开始计算，读线程可以继续读取下一部分数据了，用`write_cond`告诉写线程，计算已经完毕，可以将结果写入文件了 。而主线程需要两个条件变量，暂称为 `cal_cond` 和 `cal_cond2` , 读线程使用 `cal_cond` 告诉主线程自己已经读完这部分数据了，主线程可以开始计算了。而写线程用 `cal_cond2` 告诉主线程自己已经写完了上次计算结果，可以再次分配写入的任务了。如果读线程没有读完或者写线程没有写完，主线程都要进入等待状态。

我们知道每个条件变量都会对应一个条件以及一个互斥锁，下面分析一下各个条件的初始值，程序开始时读线程开始工作，主线程要等待读线程读完才能进行计算，所以 `read_cond` 对应的条件为 true， `cal_cond` 对应的条件的为 false，写线程必须要等待主线程计算完才可以写，并且在第一次的时候写线程肯定是空闲的， 所以 `write_cond` 对应的条件为 false，`cal_cond2` 对应的的条件为 ture。

### 数据缓冲区
当读线程读完数据，将数据存到一个缓冲区中(比如一个数组)，主线程开始计算，此时读线程又去进行读取操作。如果读线程还是将数据读到上一次读取的缓冲区中（这个缓冲区此时正在被主线程使用），那么就会出现数据竞争。为了解决这个情况，我们可以使用两个缓冲区，读线程填满一个之后再去填另外一个，使用一个变量判断当前该使用哪个缓冲区，即如下面的形式：
```c
int read_buffer_a[BUFFER_SIZE], read_buffer_b[BUFFER_SIZE];
int read_flag;

if(read_flag) {
    for(i = 0; i < BUFFER_SIZE; i++) {
        fscanf(read_arg->fp, "%d", read_buffer_a+i);
    }          
} else {
    for(i = 0; i < BUFFER_SIZE; i++) {
        fscanf(read_arg->fp, "%d", read_buffer_b + i);
    }
}
read_flag = 1 -read_flag;
```

## 完整代码
下面是完整的代码, [这里](https://github.com/zhangjikai/Pthreads-Pipeline-Demo)是github地址，可以下载下来运行一下。
```c
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdint.h>
#include <pthread.h>
#include <stdarg.h>


#define BUFFER_SIZE 10
uint32_t microseconds = 100;

// 线程信息
typedef struct _thread_info{
    pthread_t thread_id;
    pthread_mutex_t lock;
    pthread_cond_t cond;
    int run_flag;
    int buffer_flag;
    int shutdown;
} thread_info;

// 线程函数参数
typedef struct _thread_arg {
    FILE *fp;
} thread_arg;


thread_info input_info, output_info, cal_input_info, cal_output_info;
int read_buffer_a[BUFFER_SIZE], read_buffer_b[BUFFER_SIZE];
int write_buffer_a[BUFFER_SIZE], write_buffer_b[BUFFER_SIZE];


void init_resources(int n, ...) {
    va_list arg_ptr ;
    int i;
    va_start(arg_ptr, n);
    thread_info * tmp_info = NULL;

    for(i = 0; i < n; i++) {
       tmp_info = va_arg(arg_ptr, thread_info *);
       pthread_mutex_init(&(tmp_info->lock), NULL);
       pthread_cond_init(&(tmp_info->cond), NULL);
    }

    va_end(arg_ptr);
}

void free_resources(int n, ...) {
    va_list arg_ptr;
    int i;
    va_start(arg_ptr, n);
    thread_info * tmp_info = NULL;
    for(i = 0; i < n; i++) {
        tmp_info = va_arg(arg_ptr, thread_info *);
        pthread_mutex_destroy(&(tmp_info->lock));
        pthread_cond_destroy(&(tmp_info->cond));
    }
    va_end(arg_ptr);
}

void * input_task(void * args){
    thread_arg * input_arg = (thread_arg *) args;
    int i;

    while(1) {
        pthread_mutex_lock(&(input_info.lock));
        while(input_info.run_flag == 0 && !input_info.shutdown) {
            pthread_cond_wait(&(input_info.cond), &(input_info.lock));
        }
        if(input_info.shutdown) {
            break;
        }
        input_info.run_flag = 0;
        input_info.buffer_flag = 1 - input_info.buffer_flag;
        pthread_mutex_unlock(&(input_info.lock));

        if(input_info.buffer_flag) {
            for(i = 0; i < BUFFER_SIZE; i++) {
                fscanf(input_arg->fp, "%d", read_buffer_a + i);
            }
        } else {
            for(i = 0; i < BUFFER_SIZE; i++) {
                fscanf(input_arg->fp, "%d", read_buffer_b + i);
            }
        }

        pthread_mutex_lock(&(cal_input_info.lock));
        cal_input_info.run_flag = 1;
        pthread_cond_signal(&(cal_input_info.cond));
        pthread_mutex_unlock(&(cal_input_info.lock));
    }

    return NULL;
}

void * output_task(void * args){
    thread_arg * output_arg = (thread_arg *) args;
    int i;

    while(1) {
        pthread_mutex_lock(&(output_info.lock));
        while(output_info.run_flag == 0 && !output_info.shutdown) {
            pthread_cond_wait(&(output_info.cond), &(output_info.lock));
        }
        if(output_info.shutdown) {
            break;
        }
        output_info.run_flag = 0;
        output_info.buffer_flag = 1 - output_info.buffer_flag;
        pthread_mutex_unlock(&(output_info.lock));

        if(output_info.buffer_flag) {
            for(i = 0; i < BUFFER_SIZE; i++) {
                fprintf(output_arg->fp, "%d\n", write_buffer_a[i]);
                usleep(microseconds);
            }
        } else {
            for(i = 0; i < BUFFER_SIZE; i++) {
                fprintf(output_arg->fp, "%d\n", write_buffer_b[i]);
                usleep(microseconds);
            }
        }

        pthread_mutex_lock(&(cal_output_info.lock));
        cal_output_info.run_flag = 1;
        pthread_cond_signal(&(cal_output_info.cond));
        pthread_mutex_unlock(&(cal_output_info.lock));

    }
    return NULL;
}

int main(){
    FILE *fp_input, *fp_output;
    char *input_name = "input.txt";
    char *output_name = "output.txt";
    int total_nums = 100;
    int loop_nums = total_nums / BUFFER_SIZE;
    int loop_index = 0;
    int i;
    thread_arg input_arg, output_arg;

    if((fp_input = fopen(input_name, "r")) == NULL) {
        printf("can't load input file\n");
        exit(1);
    }

    if((fp_output = fopen(output_name, "w+")) == NULL) {
        printf("can't load output file\n");
        exit(1);
    }

    input_arg.fp = fp_input;
    output_arg.fp = fp_output;

    init_resources(4, &input_info, &output_info, &cal_input_info, &cal_output_info);
    input_info.buffer_flag = output_info.buffer_flag = cal_input_info.buffer_flag = 0;
    input_info.run_flag = cal_output_info.run_flag = 1;
    output_info.run_flag = cal_input_info.run_flag = 0;
    input_info.shutdown = output_info.shutdown = 0;

    pthread_create(&(input_info.thread_id), NULL, input_task, &input_arg);
    pthread_create(&(output_info.thread_id), NULL, output_task, &output_arg);

    while(1) {
        pthread_mutex_lock(&(cal_input_info.lock));
        while(cal_input_info.run_flag == 0) {
            pthread_cond_wait(&(cal_input_info.cond), &(cal_input_info.lock));
        }
        cal_input_info.buffer_flag = 1 - cal_input_info.buffer_flag;
        cal_input_info.run_flag = 0;
        pthread_mutex_unlock(&(cal_input_info.lock));

        pthread_mutex_lock(&(input_info.lock));
        if(loop_index == loop_nums - 1) {
            input_info.shutdown = 1;
        }
        input_info.run_flag = 1;
        pthread_cond_signal(&(input_info.cond));
        pthread_mutex_unlock(&(input_info.lock));

        // 这里可以使用OpenMp
        if(cal_input_info.buffer_flag) {
            for(i = 0; i < BUFFER_SIZE; i++) {
                write_buffer_a[i] = read_buffer_a[i] + 1;
            }
        } else {
            for(i = 0; i < BUFFER_SIZE; i++) {
                write_buffer_b[i] = read_buffer_b[i] + 1;
            }
        }

        pthread_mutex_lock(&(cal_output_info.lock));
        while(cal_output_info.run_flag == 0) {
            pthread_cond_wait(&(cal_output_info.cond), &(cal_output_info.lock));
        }
        cal_output_info.run_flag = 0;
        pthread_mutex_unlock(&(cal_output_info.lock));

        pthread_mutex_lock(&(output_info.lock));
        output_info.run_flag = 1;
        pthread_cond_signal(&(output_info.cond));
        pthread_mutex_unlock(&(output_info.lock));

        if(loop_index == loop_nums - 1) {
            break;
        }
        loop_index++;

    }
    pthread_mutex_lock(&(cal_output_info.lock));
    while(cal_output_info.run_flag == 0) {
        pthread_cond_wait(&(cal_output_info.cond), &(cal_output_info.lock));
    }
    cal_output_info.run_flag = 0;
    pthread_mutex_unlock(&(cal_output_info.lock));

    pthread_mutex_lock(&(output_info.lock));
    output_info.run_flag = 1;
    output_info.shutdown = 1;
    pthread_cond_signal(&(output_info.cond));
    pthread_mutex_unlock(&(output_info.lock));


    pthread_join(input_info.thread_id, NULL);
    pthread_join(output_info.thread_id, NULL);

    free_resources(4, &input_info, &output_info, &cal_input_info, &cal_output_info);
    fclose(fp_input);
    fclose(fp_output);


    return 0;
}
```

## 参考
本文主要参考了这个[Pthreads线程池](https://github.com/mbrossard/threadpool)
