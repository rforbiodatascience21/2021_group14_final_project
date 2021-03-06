# Clear workspace ---------------------------------------------------------
rm(list = ls())


# Load libraries ----------------------------------------------------------
library("tidyverse")
library("broom")
library("purrr")
library("viridis")
library("ggrepel")


# Define functions --------------------------------------------------------
source(file = "R/99_project_functions.R")


# Load data ---------------------------------------------------------------

# Wide format
merged_data_wide <- read_csv(file = gzfile("data/03_merged_data_wide.csv.gz"),
                             col_types = cols(VAX_DOSE_SERIES = col_character()))

# Long format symptom column
merged_data_long <- read_csv(file = gzfile("data/03_merged_data_long.csv.gz"), 
                             col_types = cols(HOSPDAYS = col_integer(),
                                              DIED_AFTER = col_integer(), 
                                              VAX_DOSE_SERIES = col_character(),
                                              DIED = col_character()))

# Wrangle data ------------------------------------------------------------

# Convert variables of wide format tibble to factors
merged_data_wide <- merged_data_wide %>% 
  mutate_if(is.character, 
            as.factor) %>%
  mutate_if(is.logical, 
            as.factor)

# Convert variables of long format tibble to factors
merged_data_long <- merged_data_long %>%
  mutate_if(is.character, 
            as.factor) %>%
  mutate_if(is.logical, 
            as.factor)

# Use top_n_symptoms_func() to get vector of top 20 symptoms occurring in data set.
# Use format_func() to capitalize vector elements and replace spaces with _
symptoms <- top_n_symptoms_func(data = symptoms_clean, 
                                n_symp = 20,
                                ID = "VAERS_ID") %>%
  format_func()


# Model data -------------------------------------------------------------

# Logistic regressions are fit for categorical outcome variables like DIED (Y/N)

# The "estimate" column is the log-odds ratio, so we must interpret them as follows:
# 1. If the variable is categorical, like HAS_ILLNESS, an estimate of 9.877e-01 for 
#    the "Y" group means that this group is exp(9.877e-01) = 2.685052 times more 
#    likely to die after taking the vaccine than the reference 'N' group.
# 2. If the variable is continuous, like HOSPDAYS, an estimate of 6.024e-02
#    means that, holding all else constant, one unit change in HOSPDAYS will have 
#    exp(6.024e-02) = 1.062091 units change in the odds ratio.


## 1. Patient profile vs death LogReg ------------------------------------------

# Model death outcome vs patient profile (sex, age, allergies, current illness, 
# current Covid-19, past Covid-19) to see whether a certain patient profile is 
# more likely to die after the vaccine
death_v_profile_model <- merged_data_wide %>%
  glm(formula = DIED ~ SEX + AGE_YRS + HAS_ALLERGIES + HAS_ILLNESS + HAS_COVID +
        HAD_COVID, 
      family = binomial) %>%
  tidy() %>%
  mutate(odds_ratio = exp(estimate)) 


### 1.1 LogReg Visualization ---------------------------------------------

# Make p-value bar plot
death_v_profile_model_fig_pval <- death_v_profile_model %>%
  filter(term != "(Intercept)") %>%
  ggplot(aes(x = fct_reorder(term, 
                             p.value),
             y = -log(p.value),
             fill = term)) +
  geom_bar(stat = "identity") +
  geom_hline(yintercept = -log(0.05),
             linetype = "dashed", 
             color = "black") +
  scale_fill_viridis_d() +
  scale_x_discrete(labels = c("Age", "Has illness", "Is male", "Has allergies", 
                              "Has Covid-19", "Had Covid-19")) +
  labs(title = "P-values for death ~ patient profile association",
       subtitle = "Dashed line indicates a p-value of 0.05",
       x = "Profile features",
       y = "-log(p-value)") +
  theme_minimal(base_family = "Avenir",
                base_size = 14) +
  theme(legend.position = "none", 
        axis.text.x = element_text(angle = 45, 
                                   hjust = 1, 
                                   size = 12), 
        plot.title = element_text(hjust = 0.5),
        plot.subtitle = element_text(hjust = 0.5),
        plot.margin = margin(10, 10, 10, 20))


### 1.2 LogReg Visualization ---------------------------------------------

# Make log-odds ratio bar plot
death_v_profile_model_fig_odds <- death_v_profile_model %>%
  filter(p.value < 0.05) %>%
  filter(term != "(Intercept)") %>%
  ggplot(aes(x = fct_reorder(term, 
                             estimate),
             y = estimate,
             fill = term)) +
  geom_bar(stat = "identity") +
  geom_hline(yintercept = 0,
             linetype = "dashed", 
             color = "black") +
  scale_fill_viridis_d() +
  scale_x_discrete(labels = c("Age", "Has illness", "Is male")) +
  labs(title = "Log-Odds ratio for death ~ patient profile association",
       subtitle = "A Log-Odds ratio above 0 means the feature is more common in 
       patients who die",
       x = "Profile features",
       y = "Log-Odds Ratio",
       caption = "Only features with a p-value < 0.05 are shown.") +
  theme_minimal(base_family = "Avenir",
                base_size = 14) +
  theme(legend.position = "none", 
        axis.text.x = element_text(angle = 45, 
                                   hjust = 1, 
                                   size = 12), 
        plot.title = element_text(hjust = 0.5),
        plot.subtitle = element_text(hjust = 0.5),
        plot.margin = margin(10, 10, 10, 20))


## 2. Symptoms vs. death LogReg ----------------------------------------------

# Modeling death outcome vs presence/absence of 20 most common symptoms 
# to see whether the presence/absence of certain symptoms increase risk of dying
death_v_symptoms_model <- merged_data_wide %>%
  glm(formula = str_c("DEATH ~ ", 
                      str_c(symptoms, 
                            collapse = "+")), 
      family = binomial) %>%
  tidy() %>%
  mutate(odds_ratio = exp(estimate))
  

### 2.1 LogReg Visualization -----------------------------------------

# Make p-value plot
death_v_symptoms_model_fig_pval <- death_v_symptoms_model %>%
  filter(term != "(Intercept)") %>%
  ggplot(aes(x = fct_reorder(term, 
                             p.value),
             y = -log(p.value),
             fill = term)) +
  geom_bar(stat = "identity") +
  geom_hline(yintercept = -log(0.05),
             linetype = "dashed", 
             color = "black") +
  scale_fill_viridis_d() +
  labs(title = "P-values for death ~ symptoms association",
       subtitle = "Dashed line indicates a p-value of 0.05",
       x = "Symptoms",
       y = "-log(p-value)") +
  theme_minimal(base_family = "Avenir",
                base_size = 14) +
  theme(legend.position = "none", 
        axis.text.x = element_text(angle = 45, 
                                   hjust = 1, 
                                   size = 12), 
        plot.title = element_text(hjust = 0.5),
        plot.subtitle = element_text(hjust = 0.5),
        plot.margin = margin(10, 10, 10, 20))


### 2.2. LogReg Visualization -----------------------------------------

# Make log-odds ratio plot
death_v_symptoms_model_fig_odds <- death_v_symptoms_model %>%
  filter(p.value < 0.05) %>%
  filter(term != "(Intercept)") %>%
  ggplot(aes(x = fct_reorder(term, 
                             estimate),
             y = estimate,
             fill = term)) +
  geom_bar(stat = "identity") +
  geom_hline(yintercept = 0,
             linetype = "dashed", 
             color = "black") +
  scale_x_discrete(labels = c("PRURITUS", "RASH", "DIZZINESS", "ARTHRALGIA", 
                              "HEADACHE", "MYALGIA", "PAIN IN EXTREMITY", 
                              "INJECTION SITE PAIN", "CHILLS", "PAIN", 
                              "NAUSEA", "PYREXIA", "FATIGUE", "ASTHENIA", 
                              "DYSPNOEA", "VOMITING")) +
  scale_fill_viridis_d() +
  labs(title = "Log-Odds ratio for death ~ symptoms association",
       subtitle = "A Log-Odds ratio above 0 means the symtom is more common in 
       patients who die",
       x = "Symptoms",
       y = "Log-Odds ratio",
       caption = "Only symptoms with a p-value < 0.05 are shown.") +
  theme_minimal(base_family = "Avenir",
                base_size = 14) +
  theme(legend.position = "none", 
        axis.text.x = element_text(angle = 45, 
                                   hjust = 1, 
                                   size = 12), 
        plot.title = element_text(hjust = 0.5),
        plot.subtitle = element_text(hjust = 0.5),
        plot.margin = margin(10, 10, 10, 20))


## 3. Many LogRegs ---------------------------------------------

# How much more/less likely is it to get each of the symptoms
# if you have taken an anti-inflammatory?
symptoms_v_antiinflamatory_model <- merged_data_long %>%
  select(SYMPTOM, 
         SYMPTOM_VALUE, 
         TAKES_ANTIINFLAMATORY) %>%
  group_by(SYMPTOM) %>%
  nest() %>% 
  ungroup() %>%
  mutate(mdl = map(data, 
                   ~glm(SYMPTOM_VALUE ~ TAKES_ANTIINFLAMATORY,
                        data = .x,
                        family = binomial(link = "logit")))) %>%
  mutate(mdl_tidy = map(mdl, 
                        ~tidy(.x, 
                              conf.int = TRUE))) %>% 
  unnest(mdl_tidy) %>%
  filter(term != "(Intercept)") %>%
  mutate(odds_ratio = exp(estimate)) %>%
  mutate(identified_as = case_when(p.value < 0.05 ~ "Significant",
                                   TRUE ~ "Non-significant"),
         symptom_label = case_when(identified_as == "Significant" ~ as.character(SYMPTOM),
                                   identified_as == "Non-significant" ~ ""),
         neg_log10_p = -log10(p.value)) %>%
  select(-c(data, 
            mdl))


### 3.1 Many LogRegs Visualization 1 ---------------------------

# Make Manhattan plot
symptoms_v_antiinflamatory_model_fig_manhattan <- symptoms_v_antiinflamatory_model %>% 
  ggplot(aes(x = SYMPTOM,
             y = neg_log10_p,
             colour = identified_as,
             label = symptom_label)) + 
  geom_point(alpha = 0.5,
             size = 2) +
  geom_hline(yintercept = -log10(0.05),
             linetype = "dashed") +
  geom_text_repel(size = 5) +
  scale_fill_viridis_d() +
  theme_minimal(base_family = "Avenir",
                base_size = 14) +
  theme(axis.text.x = element_blank(),
        legend.position = "bottom",
        plot.title = element_text(hjust = 0.5),
        plot.subtitle = element_text(hjust = 0.5),
        plot.margin = margin(10, 10, 10, 20)) +
  labs(title = "P-values for symptom ~ takes anti-inflammatory association",
       subtitle = "Dashed line indicates a p-value of 0.05",
       x = "Symptom",
       y = "-log10(p)")


### 3.2 Many LogRegs Visualization  ---------------------------

# Make p-value plot
symptoms_v_antiinflamatory_model_fig_odds <- symptoms_v_antiinflamatory_model %>%
  filter(p.value < 0.05) %>%
  filter(term != "(Intercept)") %>%
  ggplot(aes(x = fct_reorder(SYMPTOM, 
                             estimate),
             y = estimate,
             fill = SYMPTOM)) +
  geom_bar(stat = "identity") +
  geom_hline(yintercept = 0,
             linetype = "dashed", 
             color = "black") +
  scale_fill_viridis_d() +
  labs(title = "Log-Odds ratio for symptom ~ takes anti-inflammatory",
       subtitle = "A Log-Odds ratio above 0 means the symptom is more common in 
       people who take anti-inflamatories",
       x = "Symptoms",
       y = "Log-Odds ratio",
       caption = "Only symptoms with a p-value < 0.05 are shown.") +
  theme_minimal(base_family = "Avenir",
                base_size = 14) +
  theme(legend.position = "none", 
        axis.text.x = element_text(angle = 45, 
                                   hjust = 1, 
                                   size = 12), 
        plot.title = element_text(hjust = 0.5),
        plot.subtitle = element_text(hjust = 0.5),
        plot.margin = margin(10, 10, 10, 20))
  


# Write data --------------------------------------------------------------

# Death vs. patient profile
write_csv(death_v_profile_model, 
          file = "results/death_v_profile_model.csv")

ggsave(death_v_profile_model_fig_pval, 
       file = "results/death_v_profile_model_fig_pval.png",
       height = 7,
       width = 10)

ggsave(death_v_profile_model_fig_odds, 
       file = "results/death_v_profile_model_fig_odds.png",
       height = 7,
       width = 10)


# Death vs. symptoms
write_csv(death_v_symptoms_model, 
          file = "results/death_v_symptoms_model.csv")

ggsave(death_v_symptoms_model_fig_pval, 
       file = "results/death_v_symptoms_model_fig_pval.png",
       height = 7,
       width = 10)

ggsave(death_v_symptoms_model_fig_odds, 
       file = "results/death_v_symptoms_model_fig_odds.png",
       height = 7,
       width = 10)


# Symptoms vs. anti-inflammatory
write_csv(symptoms_v_antiinflamatory_model,
          file = "results/symptoms_v_antiinflamatory_model.csv")

ggsave(symptoms_v_antiinflamatory_model_fig_manhattan, 
       file = "results/symptoms_v_antiinflamatory_model_fig_manhattan.png",
       height = 7,
       width = 10)

ggsave(symptoms_v_antiinflamatory_model_fig_odds, 
       file = "results/symptoms_v_antiinflamatory_model_fig_odds.png",
       height = 7,
       width = 10)



