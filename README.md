# 🚀 User Retention & Churn Prediction System
## Big-Tech-Grade Production ML Project

[![Python 3.9+](https://img.shields.io/badge/python-3.9+-blue.svg)](https://www.python.org/downloads/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## 📌 Executive Summary

This project implements a **production-quality churn prediction system** designed to:
- **Predict** which customers are at risk of churning (no purchase in 60+ days)
- **Identify** early behavioral signals that precede churn
- **Optimize** business decisions using cost-sensitive evaluation
- **Segment** users into actionable risk groups
- **Recommend** data-driven retention strategies with ROI estimates

**Business Impact Focus**: This is NOT an academic exercise—it's built for real retention impact, not just model accuracy.

---

## 🎯 Business Problem

### The Challenge
E-commerce businesses lose **20-30% of customers annually** to churn. Each churned customer represents:
- Lost future revenue (Customer Lifetime Value)
- Wasted acquisition costs (CAC typically $50-150)
- Negative word-of-mouth potential

### Our Solution
A machine learning system that identifies at-risk customers **before they churn**, enabling proactive retention interventions.

---

## 📊 Churn Definition

**Churn = No purchase activity for 60 consecutive days**

### Why 60 Days?
1. **Industry Benchmark**: Retail e-commerce typically uses 30-90 day windows
2. **Data-Driven**: Analysis shows significant drop-off in return probability after 60 days
3. **Actionable**: Long enough to exclude seasonal variations, short enough to intervene
4. **Business Reality**: Retention campaigns typically run 4-8 week cycles

### Assumptions & Limitations
- Single-channel data (no omnichannel behavior)
- B2C transactions only (B2B excluded via CustomerID filtering)
- UK-centric dataset (may not generalize globally)
- Historical data only (no real-time streaming)

---

## 📁 Project Structure

```
churn-prediction-bigtech/
│
├── data/
│   ├── raw/                    # Immutable source data
│   │   └── online_retail_II.xlsx
│   └── processed/              # Transformed datasets
│       ├── customer_features.parquet
│       ├── churn_labels.parquet
│       └── model_ready.parquet
│
├── sql/                        # SQL-style queries for EDA
│   ├── 01_churn_rate_analysis.sql
│   ├── 02_activity_decline.sql
│   ├── 03_behavioral_patterns.sql
│   └── 04_cohort_analysis.sql
│
├── scripts/                    # Production-ready Python scripts
│   ├── data_validation.py
│   ├── feature_engineering.py
│   ├── model_training.py
│   └── cost_optimization.py
│
├── notebooks/                  # Analysis notebooks
│   ├── 01_data_understanding.ipynb
│   ├── 02_exploratory_analysis.ipynb
│   ├── 03_feature_engineering.ipynb
│   ├── 04_modeling.ipynb
│   └── 05_business_insights.ipynb
│
├── models/                     # Serialized models
│   ├── logistic_baseline.pkl
│   ├── random_forest.pkl
│   └── xgboost_final.pkl
│
└── README.md
```

---

## 🔬 Methodology

### Feature Engineering Categories

| Category | Features | Business Rationale |
|----------|----------|-------------------|
| **Recency** | Days since last purchase | Most predictive single feature for churn |
| **Frequency** | Purchases/month, Active days | Engagement intensity signals loyalty |
| **Monetary** | Total spend, AOV, Max order | High-value customers worth more retention effort |
| **Trend** | Frequency change, Spend decay | Early warning signals before full churn |

### Modeling Approach

1. **Logistic Regression**: Baseline + interpretability
2. **Random Forest**: Non-linear patterns
3. **XGBoost**: Final production model

### Evaluation Metrics

- **Primary**: Recall (catch churners) + Cost-weighted metrics
- **Secondary**: Precision, ROC-AUC, F1
- **Business**: Expected cost, Retention ROI

---

## 💰 Cost-Sensitive Framework

### Cost Matrix
| Prediction | Actual | Business Impact |
|------------|--------|-----------------|
| No Churn → Churns (FN) | **High Cost**: Lost CLV (~$200) |
| Churn → Doesn't (FP) | **Low Cost**: Wasted incentive (~$20) |
| Correct predictions | Optimal outcome |

### Decision Threshold
Optimized for business cost, not accuracy. Default: **0.35** (recall-biased)

---

## 📈 Key Findings

*(To be populated after analysis)*

1. **Churn Rate**: X% of customers churned in observation period
2. **Top Predictors**: Recency, frequency trend, monetary value
3. **Early Signals**: Detected X days before churn on average
4. **Model Performance**: ROC-AUC X.XX, Recall X.XX at optimal threshold

---

## 🎬 Quick Start

```bash
# 1. Install dependencies
pip install -r requirements.txt

# 2. Download data (requires Kaggle API)
kaggle datasets download -d mashlyn/online-retail-ii-uci -p data/raw/

# 3. Run full pipeline
python scripts/run_pipeline.py
```

---

## 👤 Author

Built as a portfolio project demonstrating Big-Tech-level data science practices.

---

## 📝 License

MIT License - See LICENSE for details
