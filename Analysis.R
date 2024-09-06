##########################################################################
#install necessary packages
install.packages("readxl")
install.packages("tidyverse")
install.packages("gt")
install.packages("cluster")
install.packages("ggdendro")
install.packages("purrr")
install.packages("ggplot2")
install.packages("reshape2")
#load packages
library(readxl)
library(tidyverse)
library(gt)
library(cluster)
library(ggdendro)
library(dplyr)
library(purrr)
library(ggplot2)
library(reshape2)
##########################################################################

##########################################################################
# DATA HANDLING AND EDA
##########################################################################
# Select a file interactively
selected_file <- file.choose()

#importing data from Excel
imported <- read_excel(selected_file)
#explore data set
names(imported)
summary(imported)

# Calculate the mean of the 6 bases
mean_values <- imported %>%
  select(1:6) %>%
  summarise_all(mean)

# Reshape data for plotting
mean_values <- mean_values %>%
  pivot_longer(everything(), names_to = "Column", values_to = "Mean")

# Plotting the bar chart
ggplot(mean_values, aes(x = Column, y = Mean)) +
  geom_bar(stat = "identity", fill = "skyblue") +
  labs(title = "Popularity/Importance of Features",
       x = "Base Descriptors",
       y = "Mean Value of Base Descriptors") +
  theme_minimal() +
  theme(axis.text.x = element_text(size = 8, margin = margin(t = 10)),
        axis.text.y = element_text(size = 8, margin = margin(r = 10)),
        plot.title = element_text(hjust = 0.5))
##########################################################################

##########################################################################
# STANDARDIZATION OF BASE DESCRIPTORS
##########################################################################
# Create df_base_descriptors with only the base descriptors 
df_base_descriptors <- imported %>% 
  select(1:7)
names(df_base_descriptors)
# Create df_demographic_descriptors with demographic descriptors
df_demographic_descriptors <- imported %>% 
  select(8:12)
names(df_demographic_descriptors)

#standardize values
dfz <- scale(df_base_descriptors)
##########################################################################

##########################################################################
# EVALUATING OPTIMAL NUMBER OF CLUSTERS - ELBOW METHOD
##########################################################################
# Vector to store sum of squared distances
ssd <- c()

# Define range of K (number of clusters) to test
k_values <- 1:20  # Adjust the range as needed

# Calculate SSD for each value of K
for (k in k_values) {
  # K-means clustering
  kmeans_fit <- kmeans(dfz, centers = k)
  ssd[k] <- kmeans_fit$tot.withinss  # Total within-cluster sum of squares
}

# Plot the Elbow Method graph
elbow_data <- data.frame(K = k_values, SSD = ssd)

ggplot(elbow_data, aes(x = K, y = SSD)) +
  geom_line(color = "blue") +
  geom_point(color = "red") +
  labs(x = "Number of Clusters (K)", y = "Sum of Squared Distances (SSD)",
       title = "Elbow Method for Optimal Number of Clusters") +
  scale_x_continuous(breaks = seq(min(elbow_data$K), max(elbow_data$K), by = 1)) +
  theme_minimal() +
  theme(plot.title = element_text(hjust = 0.5))

##########################################################################

##########################################################################
# EVALUATING OPTIMAL NUMBER OF CLUSTERS - SILHOUETTE METHOD
##########################################################################
# Perform clustering using k-means for different number of clusters

# function to compute average silhouette for k clusters
avg_sil <- function(k) {
  kmeans_fit <- kmeans(dfz, centers = k, nstart = 25)
  ss <- silhouette(kmeans_fit$cluster, dist(dfz))
  mean(ss[, 3])
}

# Compute and plot wss for k = 2 to k = 10
k.values <- 2:10

# extract avg silhouette for 2-15 clusters
avg_sil_values <- map_dbl(k.values, avg_sil)

plot(k.values, avg_sil_values,
     type = "b", pch = 19, frame = FALSE, 
     xlab = "Number of clusters K",
     ylab = "Average Silhouettes",
     xlim = c(2, 10))  # Set the limit of x-axis

# Calculate within-cluster sum of squares (WSS) for different number of clusters
wss <- c()

# function to compute WSS for k clusters
calc_wss <- function(k) {
  kmeans_fit <- kmeans(dfz, centers = k, nstart = 25)
  wss <- sum(kmeans_fit$withinss)
  return(wss)
}

# Compute WSS for k = 2 to k = 10
wss_values <- map_dbl(k.values[1:9], calc_wss)

# Calculate the loss of information
loss_info <- c(wss_values[1] - wss_values[2],
               wss_values[2] - wss_values[3],
               wss_values[3] - wss_values[4],
               wss_values[4] - wss_values[5],
               wss_values[5] - wss_values[6],
               wss_values[6] - wss_values[7],
               wss_values[7] - wss_values[8],
               wss_values[8] - wss_values[9])

# Plotting the loss of information against K values
plot(2:9, loss_info,
     type = "b", pch = 19, frame = FALSE, 
     xlab = "Number of clusters K",
     ylab = "Loss of Information",
     xlim = c(2, 9))  # Set the limit of x-axis

##########################################################################

##########################################################################
# CLUSTERING AND DENDOGRAM GENERATION
##########################################################################
## Ward Hierarchical Clustering
# calculate distance matrix with euclidian distance
dis <- dist(dfz, method = "euclidean")
#clustering algorithm
fit <- hclust(dis, method="ward.D2")

# Convert the hclust object to a dendrogram object
dend <- as.dendrogram(fit)

# Convert dendrogram data to ggplot-compatible format
dend_data <- dendro_data(dend)

# cut dendrogram into 3 clusters
cluster <- cutree(fit, k=3)
#explore clusters
cluster
table(cluster)

# draw dendogram with red borders around the 3 clusters
plot(fit)
rect.hclust(fit, k=3, border="red")
##########################################################################

##########################################################################
# CLUSTERS DESCRIPTION
##########################################################################
#add cluster to original data set
df_final <- cbind(imported, cluster)
names(df_final)
View(df_final)
##Description step
#calculate segment size in percentages
proportions <- table(df_final$cluster)/length(df_final$cluster)
percentages <- proportions*100
percentages

# Explore mean values of variables in clusters
segments <- df_final %>%
  group_by(cluster) %>%
  summarise_at(vars(ConstCom, TimelyInf, TaskMgm, DeviceSt, Wellness, Athlete, Style,
                    AmznP, Female, Degree, Income, Age),
               list(M = mean))

# Create visually appealing table with mean values
segments %>%
  gt() %>%
  tab_header(
    title = md("Mean Values for Clusters")
  ) %>%
  tab_style(
    style = list(
      cell_text(weight = "bold", color = "black"),
      cell_fill(color = "lightblue")
    ),
    locations = cells_body() # Add this line to specify the locations for styling
  )

##########################################################################

##########################################################################
# TARGETING - MARKET ATTRACTIVENESS
##########################################################################

# Calculate Cluster Sizes
cluster_sizes <- prop.table(table(df_final$cluster)) * 100

# Evaluate Growth Rate 
growth_rate <- c(1, 2, 3)  # Growth rates for each cluster
names(growth_rate) <- c("Cluster 1", "Cluster 2", "Cluster 3")  # Rename clusters

# Analyze Price Sensitivity
# Cluster 2 has the highest average spending
avg_spending <- c(35, 50, 85)  # Average spending for each cluster
names(avg_spending) <- c("Cluster 1", "Cluster 2", "Cluster 3")  # Rename clusters

# Create a dataframe for market attractiveness metrics
market_attractiveness <- data.frame(
  Cluster = names(cluster_sizes),
  Size = cluster_sizes,
  Growth_Rate = growth_rate,
  Avg_Spending = avg_spending
)

# Melt the data for plotting
market_attractiveness_melted <- melt(market_attractiveness, id.vars = "Cluster", na.rm = TRUE)

# Drop the first three rows from market_attractiveness_melted
market_attractiveness_melted <- market_attractiveness_melted[-c(1:3), ]

# Define soft color palette
soft_palette <- c("#40A2D8", "#B4D4FF", "#176B87")

# Define new labels for the legend
new_labels <- c("Market Size", "Growth Rate", "Average Spending")

# Plot market attractiveness metrics
ggplot(market_attractiveness_melted, aes(x = Cluster, y = value, fill = variable)) +
  geom_bar(stat = "identity", position = "dodge") +
  scale_fill_manual(values = soft_palette, name = "Metric Legend", labels = new_labels) +
  labs(title = "Market Attractiveness of Customer Segments",
       x = "Cluster",
       y = "Value") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        legend.position = "bottom", # Place legend at the bottom
        plot.title = element_text(hjust = 0.5)) # Center the title

##########################################################################