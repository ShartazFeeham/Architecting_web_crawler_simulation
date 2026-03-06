package simulation.crawler.processor.dto;

public class ProcessorStats {
    private long total;
    private long completed;
    private long pending;
    private long failed;
    private long censored;

    public ProcessorStats(long total, long completed, long pending, long failed, long censored) {
        this.total = total;
        this.completed = completed;
        this.pending = pending;
        this.failed = failed;
        this.censored = censored;
    }

    // Getters and Setters
    public long getTotal() { return total; }
    public void setTotal(long total) { this.total = total; }

    public long getCompleted() { return completed; }
    public void setCompleted(long completed) { this.completed = completed; }

    public long getPending() { return pending; }
    public void setPending(long pending) { this.pending = pending; }

    public long getFailed() { return failed; }
    public void setFailed(long failed) { this.failed = failed; }

    public long getCensored() { return censored; }
    public void setCensored(long censored) { this.censored = censored; }
}
