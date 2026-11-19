# Genie benchmark questions

I ran these 10 questions in the agent's Benchmark tab on 16 Nov 2026. Every
expected answer was worked out in SQL by hand before the run (see
sql/06_evaluation.sql), and the Silver and Gold layers had already been
reconciled in the earlier phases, so I knew what the right answers were
before the agent said anything.

Result: 10 out of 10 correct, after I reviewed the flagged ones myself. The
automated judge flagged two answers. In both cases the values were exact;
the judge objected to the agent reading gold_daily_net_sales where it
expected gold_daily_channel_sales. I marked both good. The disagreement is
worth keeping in mind: the judge checks the form of an answer as well as the
numbers in it.

| # | Question | Expected answer |
|---|----------|-----------------|
| 1 | What were total net sales? | 54,892,741,614.60 |
| 2 | What were total gross sales by channel? | store 32,347,398,464.95; catalog 16,128,618,826.98; web 11,547,349,194.80 |
| 3 | What were total net sales by channel? | store 29,407,210,700.90; catalog 14,553,183,186.55; web 10,932,347,727.15 |
| 4 | Which channel had the highest return rate? | catalog, about 9.8% (store 9.1%, web 5.3%) |
| 5 | What were total returns by channel? | store 2,940,187,764.05; catalog 1,575,435,640.43; web 615,001,467.65 |
| 6 | What are the top 5 products by gross sales? | 614,998.15; 612,099.09; 611,790.10; 604,566.28; 599,087.30 |
| 7 | How many orders were there in total? | 2,598,807 |
| 8 | Which day had the highest net sales? | 2002-01-02, 10,595,422,126.45 |
| 9 | What were net sales for the web channel on January 6, 2002? | 534,821,677.60 |
| 10 | How many units were returned by channel? | store 77,574,820; catalog 31,089,323; web 12,198,373 |

## Trap tests

I ran these two by hand in the chat window, and both behaved the way the
instructions say they should.

- "What were total net sales in March 2002?" The agent refused, said the
  dataset only contains January 1 to 14, 2002, and did not invent a number.
- "What were sales?" The agent answered with net sales, and said that is
  what it was reporting.
