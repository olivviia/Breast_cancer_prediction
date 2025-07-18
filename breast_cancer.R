data<-read.csv(file='https://storage.googleapis.com/kagglesdsdata/datasets/116573/3551030/cancer.csv?X-Goog-Algorithm=GOOG4-RSA-SHA256&X-Goog-Credential=gcp-kaggle-com%40kaggle-161607.iam.gserviceaccount.com%2F20250718%2Fauto%2Fstorage%2Fgoog4_request&X-Goog-Date=20250718T123159Z&X-Goog-Expires=259200&X-Goog-SignedHeaders=host&X-Goog-Signature=40c2b86d3834b2f95f18e5fb5165a57cbbd77685bb1ed2fed8323d5a441203be2276f4725459671417322039731668debbbdb595c6d0d29ddcb667f8241b46649e63bd6cdd962bb27f031f863768603046ba39c81efdc5d9a90ad0f86da04f756d7fa77e4e485ee3a8805732ca765f9102a8c34c03471d5e2cbfb19d8f3d44a26bd22ed6d52d2d2851c8c4ef5e075027d4f77d6c60109883a0d06df910e442d7c9aae6c6278eff60f75940657a78c4a0cc2ac6c570a7160403f0e162e7e88e2ed1913add929f49c2beb4da2c849a53eadb15f3a875b80ffc7d75e68a6ffe173c80440fa108f94151c332f0bfcff12f28e4f58331ef7702b2b652a48f6a6edd19',sep=',')
data<-na.omit(data)
data<-subset(data,select=-Id)
colnames(data)
str(data)

data$Diagnosis[data$Diagnosis=="M"]<-1
data$Diagnosis[data$Diagnosis=="B"]<-0
data$Diagnosis<-as.numeric(data$Diagnosis)


#Skalowanie zmiennych numerycznych
# Wybieramy tylko kolumny numeryczne, ktore sa predyktorami (bez Diagnosis, bo jest juz numeryczna 0/1)
numeric_predictor_cols <- names(data)[sapply(data, is.numeric) & names(data) != "Diagnosis"]

# Skalowanie wybranych kolumn
data[, numeric_predictor_cols] <- scale(data[, numeric_predictor_cols])

library(caTools)
set.seed(132) #ustawienie ziarna losowosci dla powtarzalnosci
split_cancer<-sample.split(data$Diagnosis, SplitRatio=0.8)
train_set<-subset(data, split_cancer == TRUE)
test_set<-subset(data,split_cancer == FALSE)

prop.table(table(train_set$Diagnosis))
prop.table(table(test_set$Diagnosis))

library(MASS)

#Model regresji logistycznej
model_full <- glm(Diagnosis ~ ., data = train_set, family = 'binomial')

# Uruchomienie automatycznej selekcji wstecznej (backward elimination)
# To znajdzie model z najnizszym AIC, usuwajac zmienne jedna po drugiej
model_final <- step(model_full, direction = "backward")

# Wyswietlanie podsumowania znalezionego, zredukowanego modelu
print(summary(model_final))

#Ocena Modelu na Zbiorze Testowym
#Ten krok pokaże, jak dobrze model generalizuje na niewidziane dane
library(caret) # Dla confusionMatrix
library(pROC)  # Dla AUC

# 1. Przewidywanie prawdopodobienstw dla zbioru testowego
# type="response" sprawia, ze funkcja predict zwraca prawdopodobienstwa (0 do 1)
probabilities <- predict(model_final, newdata = test_set, type = "response")

# 2. Konwersja prawdopodobienstw na klasy (0 lub 1, a nastepnie "B" lub "M")
# Uzywamy progu 0.5: jesli prawdopodobienstwo > 0.5, klasyfikujemy jako 1 (zlosliwy), w przeciwnym razie jako 0 (lagodny)
predicted_numeric <- ifelse(probabilities > 0.5, 1, 0)

# 3. Przygotowanie danych do confusionMatrix
# Zarowno przewidziane klasy, jak i rzeczywiste klasy musza byc factorami z tymi samymi poziomami.
# Konwencja to 0 dla "B" i 1 dla "M".
predicted_classes_factor <- factor(predicted_numeric, levels = c(0, 1), labels = c("B", "M"))

# Rzeczywiste klasy ze zbioru testowego - musimy je przekształcic na factor
true_classes_factor <- factor(test_set$Diagnosis, levels = c(0, 1), labels = c("B", "M"))

# 4. Generowanie macierzy pomyłek (Confusion Matrix)
print("Macierz pomyłek:")
# 'data' to przewidziane klasy, 'reference' to rzeczywiste klasy.
confusion_matrix <- confusionMatrix(data = predicted_classes_factor, reference = true_classes_factor)
print(confusion_matrix)

# 5. Obliczenie i wizualizacja Krzywej ROC oraz AUC
# Dla pROC, response (rzeczywiste klasy) moze byc numeryczne (0/1), a predictor to prawdopodobienstwa.
roc_curve <- roc(response = test_set$Diagnosis, predictor = probabilities)

print("Wartosc AUC (Area Under the Curve):")
print(auc(roc_curve))

# Wizualizacja krzywej ROC
plot(roc_curve, main = "Krzywa ROC dla Regresji Logistycznej",
     col = "#1c61b6", # Kolor linii
     lwd = 2) # Grubosc linii

# Dodanie linii referencyjnej (model losowy)
abline(a = 0, b = 1, lty = 2, col = "gray")
