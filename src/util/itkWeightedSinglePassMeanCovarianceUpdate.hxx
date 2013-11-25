/*
 * Copyright (C) 2013 Soheil Damangir - All Rights Reserved
 * You may use and distribute, but not modify this code under the terms of the
 * Creative Commons Attribution-NonCommercial-NoDerivs 3.0 Unported License
 * under the following conditions:
 *
 * Attribution — You must attribute the work in the manner specified by the
 * author or licensor (but not in any way that suggests that they endorse you
 * or your use of the work).
 * Noncommercial — You may not use this work for commercial purposes.
 * No Derivative Works — You may not alter, transform, or build upon this
 * work
 *
 * To view a copy of the license, visit
 * http://creativecommons.org/licenses/by-nc-nd/3.0/
 */
#ifndef __itkWeightedSinglePassMeanCovarianceUpdate_hxx
#define __itkWeightedSinglePassMeanCovarianceUpdate_hxx

namespace itk
{
/*
 * Weighted covariance calculation.
 * A single pass algorithm that improves both speed and accuracy compared to
 * simple two pass algorithm. The implementation allows for merging of subset
 * statistics which can be useful for parallel calculation.
 *
 * Please note that a single instance of the class is not thread-safe. It is
 * suggested to have an instance per thread and then merge afterward.
 *
 * Implementation is based on the paper:
 * Chan, Tony F.; Golub, Gene H.; LeVeque, Randall J. (1979), “Updating Formulae
 *  and a Pairwise Algorithm for Computing Sample Variances.”, Technical Report
 *  STAN-CS-79-773, Department of Computer Science, Stanford University.
 */

/*
 * Merge the states of another estimator into this estimator.
 * Tip: Useful for multi-threading
 */
template< class TState, class TMeasurement >
void WeightedSinglePassMeanCovarianceUpdate< TState, TMeasurement >::Merge(
    TState & state, const TState & otherState, const double w)
  {
  if (StateTrait::GetLength(otherState) == 0 || otherState[0] == 0)
    {
    return;
    }

  if (StateTrait::GetLength(state) == 0 || state[0] == 0)
    {
    StateTrait::SetLength(state, StateTrait::GetLength(otherState));
    for (int i = 0; i < StateTrait::GetLength(otherState); i++)
      {
      state[i] = otherState[i] * w;
      }
    return;
    }

  itkAssertOrThrowMacro(
      StateTrait::GetLength(state) == StateTrait::GetLength(otherState),
      "Length of two states to be merged should be the same. "
      "State length is " << StateTrait::GetLength(state) << " which does not "
                         "match the other state length "
                         << StateTrait::GetLength(otherState));

  const unsigned int D2 = StateTrait::GetLength(state);
  const unsigned int D = StateToMeasurementDim(D2);

  // calculate effect of the other estimator
  const double f = state[0] * (otherState[0] * w)
      / (state[0] + (otherState[0] * w));
  MeasurementType dX;
  MeasurementTrait::SetLength(dX, D);
  // calculate deviation from current mean
  for (int i = 0; i < D; i++)
    {
    dX[i] = (otherState[i + 1] / otherState[0]) - (state[i + 1] / state[0]);
    }

  // Update the weight
  state[0] += otherState[0] * w;

  // Update the mean
  for (int i = 1; i < D + 1; i++)
    {
    state[i] += otherState[i] * w;
    }

  for (int r = 0, i = D + 1; r < D; r++)
    for (int c = 0; c <= r; c++, i++)
      {
      state[i] += otherState[i] * w + f * dX[r] * dX[c];
      }
  }

/*
 * Add a weighted sample and update the state
 */
template< class TState, class TMeasurement >
void WeightedSinglePassMeanCovarianceUpdate< TState, TMeasurement >::UpdateState(
    const TMeasurement & r, TState& state, double w)
  {
  const unsigned int D = MeasurementTrait::GetLength(r);
  const unsigned int D2 = MeasurementToStateDim(D);

  if (StateTrait::GetLength(state) == 0 || state[0] == 0)
    {
    StateTrait::SetLength(state, D2);
    state.Fill(0.);
    }
  else
    {
    itkAssertOrThrowMacro(
        StateTrait::GetLength(state) == D2,
        "Input dimension does not follow the expected dimension. "
        "State dimension is " << StateTrait::GetLength(state) << " however it "
                              "should be "
                              << D2 << " according to length of measurement ("
                              << D << ")");
    }

  if (state[0] == 0)
    {
    state[0] = w;
    for (int i = 0; i < D; i++)
      {
      state[i + 1] = w * r[i];
      }
    }
  else
    {
    // calculate current effect of the sample
    const double f = state[0] * w / (state[0] + w);

    MeasurementType dX;
    MeasurementTrait::SetLength(dX, D);
    // calculate deviation from current mean
    for (int i = 0; i < D; i++)
      {
      dX[i] = r[i] - (state[i + 1] / state[0]);
      }

    // Update the mean
    for (int i = 1; i < D + 1; i++)
      {
      state[i] += w * r[i - 1];
      }

    for (int r = 0, i = D + 1; r < D; r++)
      for (int c = 0; c <= r; c++, i++)
        {
        state[i] += f * dX[r] * dX[c];
        }
    // Update the weight
    state[0] += w;
    }
  }

/**Calculate Mahalanobis distance of the input point using the READY stare */
template< class TState, class TMeasurement >
typename WeightedSinglePassMeanCovarianceUpdate< TState, TMeasurement >::ScalarRealType WeightedSinglePassMeanCovarianceUpdate<
    TState, TMeasurement >::Distance(const StateType& state,
                                     const MeasurementType & r)
  {
  const unsigned int D = MeasurementTrait::GetLength(r);
  MeasurementType mv;
  MeasurementTrait::SetLength(mv, D);

  /** Compute ( mv - mean ) */
  for (int i = 0; i < D; i++)
    {
    mv[i] = r[i] - GetMeanElement(state, i);
    }

  /** Compute md=( mv - mean )^t InverseCovariance ( mv - mean ) */
  ScalarRealType md = 0;
  for (int i = 0; i < D; i++)
    {
    for (int j = 0; j < D; j++)
      {
      md += mv[j] * mv[i] * GetCovElement(state, i, j);
      }
    }

  return md;
  }

/**Calculate statistics for difference between two states */
template< class TState, class TMeasurement >
typename WeightedSinglePassMeanCovarianceUpdate< TState, TMeasurement >::ScalarRealType WeightedSinglePassMeanCovarianceUpdate<
    TState, TMeasurement >::Difference(const StateType& state1,
                                       const StateType& state2)
  {
  const unsigned int D2 = StateTrait::GetLength(state1);
  const unsigned int D = StateToMeasurementDim(D2);
  MeasurementType mv;
  MeasurementTrait::SetLength(mv, D);

  /** Compute ( mv - mean ) */
  for (int i = 0; i < D; i++)
    {
    mv[i] = GetMeanElement(state1, i) - GetMeanElement(state2, i);
    }

  /** Compute md=( mv - mean )^t InverseCovariance ( mv - mean ) */
  ScalarRealType md = 0;
  for (int i = 0; i < D; i++)
    {
    for (int j = 0; j < D; j++)
      {
      md += mv[j] * mv[i] * GetCovElement(state1, i, j);
      }
    }

  return md;
  }

template< class TState, class TMeasurement >
int WeightedSinglePassMeanCovarianceUpdate< TState, TMeasurement >::Orientation(
    const StateType& state, const MeasurementType & r)
  {
  const unsigned int D = MeasurementTrait::GetLength(r);
  int orient = 0;
  for (int i = 0; i < D; i++)
    {
    if (r[i] > state[i + 1])
      {
      orient |= 1 << i;
      }
    }
  return orient;
  }
/*
 * Calculate the current estimate of mean vector
 */
template< class TState, class TMeasurement >
typename WeightedSinglePassMeanCovarianceUpdate< TState, TMeasurement >::MeanType WeightedSinglePassMeanCovarianceUpdate<
    TState, TMeasurement >::GetMean(const TState& state)
  {
  const unsigned int D2 = StateTrait::GetLength(state);
  const unsigned int D = StateToMeasurementDim(D2);
  MeanType mean;
  NumericTraits< MeanType >::SetLength(mean, D);
  for (int i = 0; i < D; i++)
    {
    mean[i] = state[i + 1] / state[0];
    }
  return mean;
  }

/*
 * Calculate the current estimate of covariance matrix
 */
template< class TState, class TMeasurement >
typename WeightedSinglePassMeanCovarianceUpdate< TState, TMeasurement >::CovarianceType WeightedSinglePassMeanCovarianceUpdate<
    TState, TMeasurement >::GetCovariance(const TState& state)
  {
  const unsigned int D2 = StateTrait::GetLength(state);
  const unsigned int D = StateToMeasurementDim(D2);
  CovarianceType cov;
  cov.SetSize(D, D);
  for (int r = 0, i = D + 1; r < D; r++)
    for (int c = 0; c <= r; c++, i++)
      cov(c, r) = cov(r, c) = state[i] / (state[0] - 1.);

  return cov;
  }

template< class TState, class TMeasurement >
void WeightedSinglePassMeanCovarianceUpdate< TState, TMeasurement >::MakeReady(
    StateType& state)
  {
  const unsigned int D2 = StateTrait::GetLength(state);
  if (state[0] < 1)
    {
    for (int i = 0; i < D2; i++)
      {
      state[i] = 0;
      }
    return;
    }

  const unsigned int D = StateToMeasurementDim(D2);

  double divisor = state[0] - 1.0;

  vnl_matrix< double > cov(D, D);
  for (int r = 0, i = D + 1; r < D; r++)
    for (int c = 0; c <= r; c++, i++)
      cov(c, r) = cov(r, c) = state[i] / (divisor);

  vnl_matrix< double > inv_cov = vnl_matrix_inverse< double >(cov);

  for (int r = 0, i = D + 1; r < D; r++)
    {
    state[r + 1] /= divisor;
    for (int c = 0; c <= r; c++, i++)
      state[i] = inv_cov(c, r);
    }

  }

template< class TState, class TMeasurement >
typename WeightedSinglePassMeanCovarianceUpdate< TState, TMeasurement >::StateType WeightedSinglePassMeanCovarianceUpdate<
    TState, TMeasurement >::GetState(const MeanType& mean,
                                     const CovarianceType& cov)
  {
  const unsigned int D = NumericTraits< MeanType >::GetLength(mean);
  const unsigned int D2 = MeasurementToStateDim(D);

  StateType state;
  StateTrait::SetLength(state, D2);
  state[0] = 2;
  for (int r = 0, i = D + 1; r < D; r++)
    {
    state[r + 1] = mean[r];
    for (int c = 0; c <= r; c++, i++)
      state[i] = cov.GetVnlMatrix()(c, r);
    }
  return state;
  }

template< class TState, class TMeasurement >
void WeightedSinglePassMeanCovarianceUpdate< TState, TMeasurement >::PrintState(
    const StateType& state)
  {
  const unsigned int D2 = StateTrait::GetLength(state);
  for (int i = 0; i < D2; i++)
    {
    std::cout << state[i] << " ";
    }
  std::cout << std::endl;
  }

} // end namespace itk

#endif
