/*************************************************************************
 *
 *************************************************************************
 */
#include <stdio.h>
#include <stdarg.h>
#include <stdint.h>
#include <ctype.h>

//#include "opcode.h"

void LogOpen(char *file);
void LogFlush(void);
void LogClose(void);

// ========================================================================
#define	DEBUG_PRINT	        1      // 1: ログ出力を有効にする
#define	DEBUG_ALWAYS_FLUSH  1      // 1: LogPrintするたびに、LogFlush()する（ハングした場合でも、そこまでのログは残ります）
#define	DEFAULT_LOGFILE	   "log.txt"  // オープン省略時の、ログ出力ファイル名
// ========================================================================
#define MAX_BUF_SIZ 1024

//extern 
char opt_t=1; // Trace Log

FILE *logfp=NULL;


/**
 * @brief MAC版：log.txtをオープンする.
 */
static	FILE	*log_open(const char *file)
{
	return fopen("log.txt" , "wb");
}

/**
 * @brief LogOpen(Filename) で、ログファイルを書き込みオープンする.
 *
 */
void LogOpen(char *file)
{
	if(logfp != NULL) return;
	logfp = log_open(file);
}

/**
 * @brief LogFlush() で、ログファイルを一旦Flushする (吐き出す).
 *
 */
void LogFlush(void)
{
	if(logfp) {
		fflush(logfp);
	}
}

/**
 * @brief LogClose() で、ログファイルを閉じる.
 *
 */
void LogClose(void)
{
	if(logfp) {
		fclose(logfp);
		logfp = NULL;
	}
}

/**
 * @brief LogPrint( fmt , arg ... ) で カレントの log.txt に出力.
 *
 */
void LogPrint(char *format,...)
{
	char buffer[MAX_BUF_SIZ+4];
	int  buflen;
	
	if(opt_t==0) {	// Trace Logなし.
		return;
	}

	va_list arg;
	va_start( arg, format );
	buflen = vsnprintf( buffer, MAX_BUF_SIZ , format, arg );
	va_end( arg );

	// 未オープンの場合は、デフォルト・ログファイルをオープンする.
	if(logfp==NULL) {
		LogOpen(DEFAULT_LOGFILE);   //	"log.txt"  // オープン省略時の、ログ出力ファイル名
	}

	if(	buflen > MAX_BUF_SIZ) {
		buflen = MAX_BUF_SIZ;
	}
	// 念のため:ゼロ終端.
	buffer[buflen] = 0;

	// オープンに失敗していたら、書かない.
	if(logfp) {
		fwrite(buffer,1,buflen,logfp);
#if	DEBUG_ALWAYS_FLUSH        // 1: LogPrintするたびに、LogFlush()する（ハングした場合、そこまでのログは見たい）
		LogFlush();
#endif
	}
}

