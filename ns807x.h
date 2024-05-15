/*
 *	A simple NS806x implementation
 */

struct ns8070 {
    uint16_t pc;
    uint16_t t;
    uint16_t sp;
    uint16_t p2;
    uint16_t p3;
    uint8_t a;
    uint8_t e;
    uint8_t s;
    uint8_t *rom;
//    uint8_t ram[64];

    uint8_t i;
    uint8_t int_latch;
#define INT_A	1
#define INT_B	2
    uint8_t input;

    int trace;			/* TODO */
};

#define TRACE_MEM	1
#define TRACE_IO	2
#define TRACE_CPU	4

extern struct ns8070 *ns8070_create(uint8_t *rom);
extern void ns8070_reset(struct ns8070 *cpu);
extern void ns8070_trace(struct ns8070 *cpu, unsigned int onoff);
extern unsigned int ns8070_execute_one(struct ns8070 *cpu);
extern unsigned int ns8070_executes(struct ns8070 *cpu);
extern void ns8070_set_a(struct ns8070 *cpu, unsigned int a);
extern void ns8070_set_b(struct ns8070 *cpu, unsigned int b);
extern void	ns8070_emu_chario();
extern int  ns8070_emu_getc(void);
extern void ns8070_emu_putc(char r);

/*
 *	Helpers required by the implementor
 */

extern uint8_t mem_read(struct ns8070 *cpu, uint16_t addr);
extern void mem_write(struct ns8070 *cpu, uint16_t addr, uint8_t val);
extern void flag_change(struct ns8070 *cpu, uint8_t fbits);
#define S_CL	0x80		/* Carry / Link */
#define S_OV	0x40		/* Signed overflow */
#define S_SB	0x20		/* Buffered input B */
#define S_SA	0x10		/* Buffered input A */
#define S_F3	0x08		/* CPU flag outputs */
#define S_F2	0x04		/* Basically 3 GPIO */
#define S_F1	0x02		/* lines for bitbang */
#define S_IE	0x01		/* Interrupt enable */

