/* Bare-metal C/ABI experiment: no libc and no initialized globals. */
#include <stdint.h>

__attribute__((noinline))
int add3(int a, int b)
{
    int sum = a + b;
    sum += 3;
    return sum;
}

int main(void)
{
    volatile int a = 5;
    volatile int b = 7;
    int result = add3(a, b);

    *(volatile uint32_t *)0x1000u = (uint32_t)result;       /* 15 */
    *(volatile uint32_t *)0x1004u = (uint32_t)(result + 1); /* 16 */
    return 0;
}
