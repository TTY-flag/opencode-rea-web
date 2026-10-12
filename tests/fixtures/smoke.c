__attribute__((noinline)) int rea_add(int left, int right) {
    return left + right;
}
int main(void) {
    volatile int value = rea_add(7, 11);
    return value == 18 ? 0 : 1;
}
