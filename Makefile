
#CFLAGS = -Wall -pedantic -g3 -Werror
#CFLAGS = -Wall -pedantic -g3
CFLAGS = -Wall -O3

#
# Default Target
#
all1:	nybbles 
all2:	scmp2


#
# Test (SC/MP-III)
#
tr:
	./nybbles -r 8073NIBL.bin -d 7   2>trace.log

trace:
	./nybbles -r 8073NIBL.bin -d 7   2>trace.log

test:
	./nybbles -r 8073NIBL.bin


#
# Test (SC/MP-II)
#
test2:
	./scmp2 -r NIBL.bin 

debug2:
	./scmp2 -r NIBL.bin -d 7





nybbles: nybbles.o ns807x.o
	cc -g3 nybbles.o ns807x.o -o nybbles

scmp2:	scmp2.o ns806x.o debug.o
	cc -g3 scmp2.o ns806x.o debug.o -o scmp2

clean:
	-rm *.o
	-rm *~
	-rm err
	-rm nybbles


SRCS := $(subst ./,,$(shell find . -name '*.c'))
DEPDIR := .deps
DEPFLAGS = -MT $@ -MMD -MP -MF $(DEPDIR)/$*.d

COMPILE.c = $(CC) $(DEPFLAGS) $(CFLAGS) $(CPPFLAGS) $(TARGET_ARCH) -c

%.o : %.c
%.o : %.c $(DEPDIR)/%.d | $(DEPDIR)
	$(COMPILE.c) $(OUTPUT_OPTION) $<

$(DEPDIR): ; @mkdir -p $@

DEPFILES := $(SRCS:%.c=$(DEPDIR)/%.d)
$(DEPFILES):


# include $(wildcard $(DEPFILES))
