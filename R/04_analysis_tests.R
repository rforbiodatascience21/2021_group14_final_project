# Clear workspace ---------------------------------------------------------
rm(list = ls())


# Load libraries ----------------------------------------------------------
library("tidyverse")
library("infer")


# Define functions --------------------------------------------------------
source(file = "R/99_project_functions.R")


# Load data ---------------------------------------------------------------

# Wide format
merged_data_wide <- read_csv(file = gzfile("data/03_merged_data_wide.csv.gz"),
                             col_types = cols(VAX_DOSE_SERIES = col_character()))


# Wrangle data ------------------------------------------------------------

# Convert variables to factors
merged_data_wide <- merged_data_wide %>% 
  mutate_if(is.character, 
            as.factor) %>%
  mutate_if(is.logical, 
            as.factor)


# Model data --------------------------------------------------------------

# We wish to do proportion tests for DIED vs. different variables based on the following:

# 1. Null hypothesis: 
# the proportions are the same. The two variables are independent.

# 2. Assumptions:
# Data in contingency table is presented in counts (not in percent)
# All cells contain more than 5 observations
# Each observation contributes to one group only
# Groups are independent
# The variables under study are categorical
# The sample is, supposedly, reasonably random


## 1. Chi-squared tests  -------------------------------------------------------


### 1.1 Manufacturer vs. died -------------------------------------------------

# Null hypothesis: the proportion of people that died after vaccination with X 
# vaccine is equal to the proportion of people that died after vaccination with Y vaccine.

# Do chi-square test using chisq_func()
manu_v_died_test <- chisq_func(DIED, 
                               VAX_MANU)

# Extract p-value
manu_v_died_pval <- manu_v_died_test %>%
  pluck("p.value") %>%
  format.pval(digits = 2)



### 1.2 Sex vs. died  -----------------------------------------------------------

# Null hypothesis: the proportion of people of gender X that died after 
# vaccination is equal to the proportion of people of gender Y that died
# after vaccination

# Do chi-square test
sex_v_died_test <- chisq_func(DIED, 
                              SEX)

# Extract p-values
sex_v_died_pval <- sex_v_died_test %>%
  pluck("p.value") %>% 
  format.pval(digits = 2)


# 2. Contingency tables ---------------------------------------------------------

## 2.1 Manufacturer vs. died  ---------------------------------------------------------
contingency_table1 <- merged_data_wide %>%
  group_by(DIED, 
           VAX_MANU) %>%
  summarise(n = n()) %>%
  pivot_wider(names_from = VAX_MANU,
              values_from = n)

## 2.2 Sex vs. died  ---------------------------------------------------------
contingency_table2 <- merged_data_wide %>%
  filter(!is.na(SEX)) %>% 
  group_by(DIED, 
           SEX) %>%
  summarise(n = n()) %>%
  pivot_wider(names_from = SEX,
              values_from = n)


# 3. Visualizations -------------------------------------------------------

## 3.1 Manufacturer vs. died ----------------------------------------------

# Make bar plot showing manufacturer vs. died. 
# Counts of deaths per group (per vaccine) are relative to the number of 
# subjects in the group. 
manu_v_death <- merged_data_wide %>%
  count(VAX_MANU, 
        DIED) %>%
  group_by(VAX_MANU) %>%
  mutate(total = sum(n)) %>%
  filter(DIED == "Y") %>%
  summarise(prop = n/total, 
            .groups = "rowwise") %>%
  ggplot(.,
         aes(x = fct_reorder(VAX_MANU, 
                             desc(prop)),
             y = prop,
             fill = VAX_MANU)) +
  geom_bar(position = "dodge",
           stat = "identity",
           alpha = 0.8) +
  scale_y_continuous(labels = scales::percent) +
  scale_fill_viridis_d() +
  labs(title = "Relative occurence of death by vaccine manufacturer",
       subtitle = str_c("p-value:", 
                        manu_v_died_pval), 
       x = "Vaccine manufacturer",
       y = "Relative occurence of death") +
  theme_minimal(base_family = "Avenir") +
  theme(legend.position = "none",
        plot.margin = margin(10, 20, 10, 10),
        plot.title = element_text(hjust = 0.5), 
        plot.subtitle = element_text(hjust = 0.5))


## 3.1 Sex vs. died -----------------------------------------------------

# Make bar plot showing sex vs. died.
# Counts of deaths per group (per vaccine) are relative to the number of 
# subjects in the group. 
sex_v_death <- merged_data_wide %>%
  filter(!is.na(SEX)) %>%
  count(SEX, DIED) %>%
  group_by(SEX) %>%
  mutate(total = sum(n)) %>%
  filter(DIED == "Y") %>%
  summarise(prop = n/total, .groups = "rowwise") %>%
  ggplot(.,
         aes(x = fct_reorder(SEX, desc(prop)),
             y = prop,
             fill = SEX, 
             drop_na = TRUE)) +
  geom_bar(position = "dodge",
           stat = "identity",
           alpha = 0.8) +
  scale_y_continuous(labels = scales::percent) +
  scale_fill_viridis_d() +
  labs(title = "Relative occurence of death by vaccine manufacturer",
       subtitle = str_c("p-value:", sex_v_died_pval),
       x = "Sex",
       y = "Relative occurence of death") +
  theme_minimal(base_family = "Avenir") +
  theme(legend.position = "none",
        plot.margin = margin(10, 20, 10, 10),
        plot.title = element_text(hjust = 0.5),
        plot.subtitle = element_text(hjust = 0.5))



# Write data --------------------------------------------------------------

# Save contingency tables
write_csv(x = contingency_table1,
          file = "results/contingency_table1.csv")

write_csv(x = contingency_table2,
          file = "results/contingency_table2.csv")


# Save manufacturer/sex vs. death plots
ggsave(manu_v_death, 
       file = "results/manu_v_death.png",
       height = 5,
       width = 8)

ggsave(sex_v_death,
       file = "results/sex_v_death.png",
       height = 5,
       width = 8)

