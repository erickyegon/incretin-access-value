# Wild cluster bootstrap for the Sun-Abraham post-period average (step 13 part a; split out so it can be rerun alone). Webb weights, 9,999 draws,
# by state, on the mean of the 20 imputed outcomes; seed SEED_BASE + 9000. Updates outputs/cache/sunab_wild_placebo.rds.
source(here::here("R", "prep.R"))
panel <- get_mart("mart_did_panel")
imps <- readRDS(here::here("outputs", "cache", "imputed_panels.rds"))
cache <- readRDS(here::here("outputs", "cache", "sunab_wild_placebo.rds"))
dat_mean <- build_data(panel, imp = imps[[1]])
dat_mean$y <- rowMeans(sapply(seq_len(M_IMP), function(m) build_data(panel, imp = imps[[m]])$y))
fm <- sa_design(dat_mean)
fm$cell <- factor(fm$cell, levels = c("ref", setdiff(sort(unique(fm$cell)), "ref")))
fm$idf <- factor(fm$id); fm$tf <- factor(fm$t)
# Re-parameterise so that the post-period average theta = sum_c w_c delta_c is ONE coefficient (fwildclusterboot gives confidence intervals by test
# inversion for a single parameter): drop the first post cell c0 from the dummies and add x0 = d_c0 / w_c0, and for every other post cell use
# d_c - (w_c / w_c0) d_c0; the coefficient on x0 is theta. The fit is identical to the saturated interaction regression.
post <- fm |> filter(as.character(cell) != "ref", e >= 0) |> count(cell, name = "n_obs") |> mutate(w = n_obs / sum(n_obs))
D <- model.matrix(~ 0 + cell, data = fm); colnames(D) <- sub("^cell", "", colnames(D)); D <- D[, colnames(D) != "ref", drop = FALSE]
c0 <- as.character(post$cell[1]); w0 <- post$w[1]
X <- D
for (i in seq_len(nrow(post))[-1]) { ci <- as.character(post$cell[i]); X[, ci] <- D[, ci] - (post$w[i] / w0) * D[, c0] }
X[, c0] <- D[, c0] / w0
colnames(X) <- make.names(colnames(X))
x0 <- make.names(c0)
dfm <- data.frame(y = fm$y, X, idf = fm$idf, tf = fm$tf, id = fm$id, check.names = FALSE)
lmod <- lm(reformulate(c(colnames(X), "idf", "tf"), response = "y"), data = dfm)
point <- unname(coef(lmod)[x0])
set.seed(SEED_BASE + 9000L); dqrng::dqset.seed(SEED_BASE + 9000L)  # fwildclusterboot draws from dqrng: both seeds are needed for reproducibility
bt <- fwildclusterboot::boottest(lmod, clustid = "id", param = x0, B = 9999, type = "webb", engine = "R-lean", nthreads = 1, conf_int = TRUE)
# fwildclusterboot's R-lean engine returns no test-inversion interval, so the interval is the symmetric wild bootstrap-t interval:
# theta_hat +/- se_CRV1 x q_0.95(|t*|), with t* the 9,999 null-imposed Webb bootstrap t statistics and se_CRV1 = theta_hat / t_stat.
se_crv1 <- abs(point / bt$t_stat); q95 <- unname(quantile(abs(bt$t_boot), 0.95))
cat("t_stat", bt$t_stat, "se_CRV1", se_crv1, "q95(|t*|)", q95, "p", bt$p_val, "
")
wild <- tibble(point_estimate = point, p_value_wild_webb = bt$p_val, ci_low = point - q95 * se_crv1, ci_high = point + q95 * se_crv1, se_crv1 = se_crv1,
               q95_abs_t_boot = q95, draws = 9999, cluster = "state", imputation = "mean of 20 imputed outcomes",
               ci_method = "symmetric wild bootstrap-t (R-lean engine returns no inversion interval)")
cache$wild <- wild
saveRDS(cache, here::here("outputs", "cache", "sunab_wild_placebo.rds"))
print(wild)
