# ChurnSense

Customer retention prediction system using machine learning.

## Overview

Predicts which customers will churn (60+ days inactive) using behavioral features from transaction data. Uses a cost-sensitive approach prioritizing recall.

**Results:** 80%+ recall, optimized threshold at 0.35, ROI-positive retention strategy.

## Quick Start

```bash
git clone https://github.com/Anujpatel04/ChurnSense.git
cd ChurnSense
pip install -r requirements.txt
```

Run notebooks 00 through 08 in order.

## Dataset

**Dataset:** Online Retail II  
**Source:** UCI Machine Learning Repository (via Kaggle)  
**Type:** Transaction-level behavioral data

### Characteristics

- Real-world e-commerce transactions
- Time-stamped user activity
- Suitable for behavioral modeling and retention analysis

### Download

Raw data is downloaded programmatically using kagglehub to ensure reproducibility:

```python
import kagglehub

path = kagglehub.dataset_download("mashlyn/online-retail-ii-uci")
print("Path to dataset files:", path)
```

Or via Kaggle CLI:

```bash
kaggle datasets download -d mashlyn/online-retail-ii-uci -p data/raw --unzip
```

> Raw data stored under `data/raw/` remains immutable throughout the project.

## Structure

```
notebooks/
  00_problem_framing.ipynb
  01_data_understanding.ipynb
  02_exploratory_analysis.ipynb
  03_feature_engineering.ipynb
  04_label_creation.ipynb
  05_modeling.ipynb
  06_cost_sensitive_evaluation.ipynb
  07_user_segmentation.ipynb
  08_final_insights.ipynb
data/
models/
sql/
```

## Methodology

**Churn:** No purchase in 60 days

**Features:** Recency, frequency, monetary, behavioral trends

**Models:** Logistic Regression (baseline), Random Forest, XGBoost (production)

| Model               | ROC-AUC |
| ------------------- | ------- |
| Logistic Regression | ~0.75   |
| Random Forest       | ~0.82   |
| XGBoost             | ~0.85   |

## Cost Framework

| Outcome        | Cost |
| -------------- | ---- |
| Missed churner | $200 |
| False alarm    | $20  |
| Ratio          | 10:1 |

Optimal threshold: 0.35

## Segments

| Segment     | Churn Prob | Action             |
| ----------- | ---------- | ------------------ |
| High Risk   | 70%+       | Immediate outreach |
| Medium Risk | 40-70%     | Targeted offers    |
| Low Risk    | 20-40%     | Nurture campaigns  |
| Safe        | <20%       | Standard marketing |
