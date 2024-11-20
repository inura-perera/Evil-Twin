# Evil Twin detection using Machine Learning
## Introduction
An Evil Twin is a fake Wi-Fi network set up to trick people into connecting to it, thinking it’s a legitimate network, like one in a coffee shop or airport. Hackers create this network to steal personal information, such as passwords, credit card details, or emails, from those who connect. It works because it looks exactly like a real network, even using the same name. Once someone joins, their data can be monitored or stolen. It’s like sitting next to someone who secretly spies on everything you’re doing online. 

<b>Always double-check Wi-Fi networks before connecting!</b>

Existing security measures for Wi-Fi networks often struggle to effectively detect and mitigate these sophisticated attacks. Traditional approaches rely heavily on signature-based detection and static rules, which lack adaptability and real-time effectiveness in open Wi-Fi settings. While machine learning (ML) has shown promise for enhancing network security, most current ML-based models remain theoretical and demonstrate high accuracy with offline datasets yet fail to deliver practical solutions in real-time scenarios.

## System Overview
<div align="center">
  <img src="/Assets/system_diagram.png" alt="System Diagram"/>
</div>

The system starts by preparing a dataset to ensure the data is clean and relevant. Once ready, machine learning (ML) techniques are used to train a model. The goal is to choose the model that performs the best with high accuracy.

Next, a packet capture tool collects Wi-Fi data in monitor mode to gather detailed network information. This data is saved and converted into JSON format, making it easier to work with. The JSON data is then turned into a CSV file, which is sent to the trained ML model for predictions. Finally, the model's results are shared with the user, offering useful insights or recommendations.

## Dataset
<a href="https://icsdweb.aegean.gr/awid/awid2" target="_blank">AWID2 dataset</a> , a wireless intrusion detection evaluation dataset developed by the University of the Aegean.

<b>Reference</b> : <br>
`
C. Kolias, G. Kambourakis, A. Stavrou and S. Gritzalis, "Intrusion Detection in 802.11 Networks: Empirical Evaluation of Threats and a Public Dataset," in IEEE Communications Surveys \& Tutorials, vol. 18, no. 1, pp. 184-208, Firstquarter 2016, doi: 10.1109/COMST.2015.2402161.
`

## Research Gap
This research addresses a significant gap in the work of Asaduzzaman, Majib, and Rahman (2020), who proposed a Wi-Fi frame analysis-based detection scheme and achieved 91.24% accuracy using a J48 decision tree model. 

However, their approach remains theoretical and limited in scope. In contrast, this study goes beyond theoretical models by leveraging various machine learning algorithms to provide a practical, real-time solution for improving accuracy. This research not only offers a robust solution for real-world deployment but also enhances detection accuracy beyond the 91.24% achieved by prior study.

<b>Reference</b> : <br>
`
M. Asaduzzaman, M. S. Majib and M. M. Rahman, "Wi-Fi Frame Classification and Feature Selection Analysis in Detecting Evil Twin Attack," 2020 IEEE Region 10 Symposium (TENSYMP), Dhaka, Bangladesh, 2020, pp. 1704-1707, doi: 10.1109/TENSYMP50017.2020.9231042.
`
## Preprocessing and Model Training (Random Forest, KNN, Naive Bayes)
The `Research-Evil_Twin_Detection.ipynb` notebook provides a detailed walkthrough of the preprocessing steps, model training, results, and analysis. Below is a summary of the key steps and findings:

### Key Steps:
#### Dataset Preprocessing
  - Ensures data quality and relevance through:
    - Cleaning
    - Handling missing values
    - Feature selection
  - Prepares the data for efficient and accurate model training.

#### Model Training
  - Three machine learning algorithms are used:
    - Random Forest
    - K-Nearest Neighbors (KNN)
    - Naive Bayes
#### Results
| Model | Accuracy (%) |
| ------ | ------ |
| Random Forest | 99.9186 |
| KNN | 82.1312 |
| Naive Bayes | 53.5610 |

## Prediction Results on Real Wi-Fi Data
